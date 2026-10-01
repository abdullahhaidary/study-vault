import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'backup_exceptions.dart';
import 'backup_io.dart';
import 'backup_manifest.dart';

/// Relative paths inside a `.svbackup` ZIP.
abstract final class BackupArchiveLayout {
  static const root = 'backup';
  static const manifestPath = 'backup/manifest.json';
  static const databasePath = 'backup/database/study_vault.sqlite';
  static const filesPrefix = 'backup/files/study_vault_files/';
}

class ValidatedBackup {
  const ValidatedBackup({
    required this.archiveFile,
    required this.manifest,
    required this.extractedDir,
  });

  final File archiveFile;
  final BackupManifest manifest;
  final Directory extractedDir;
}

/// Create / inspect / extract Study Vault backup archives (ZIP under the hood).
abstract final class BackupArchive {
  /// Build a `.svbackup` ZIP at [outputFile] from prepared content.
  static Future<void> createArchive({
    required File outputFile,
    required File manifestFile,
    required File databaseSnapshot,
    required List<({File file, String relativePath})> materialFiles,
    void Function(int done, int total)? onMaterialProgress,
  }) async {
    await outputFile.parent.create(recursive: true);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final encoder = ZipFileEncoder();
    encoder.create(outputFile.path);
    try {
      await encoder.addFile(manifestFile, BackupArchiveLayout.manifestPath);
      await encoder.addFile(databaseSnapshot, BackupArchiveLayout.databasePath);

      final total = materialFiles.length;
      for (var i = 0; i < materialFiles.length; i++) {
        final entry = materialFiles[i];
        final archiveName =
            '${BackupArchiveLayout.filesPrefix}${entry.relativePath}';
        await encoder.addFile(entry.file, archiveName);
        onMaterialProgress?.call(i + 1, total);
      }
    } finally {
      await encoder.close();
    }
  }

  /// Open [archiveFile], extract to [destination], validate required layout.
  static Future<ValidatedBackup> extractAndValidate(
    File archiveFile,
    Directory destination, {
    required int currentSchemaVersion,
  }) async {
    if (!await archiveFile.exists()) {
      throw const BackupValidationException('Backup file was not found.');
    }

    await deleteIfExists(destination);
    await destination.create(recursive: true);

    try {
      final input = InputFileStream(archiveFile.path);
      try {
        final archive = ZipDecoder().decodeStream(input);
        await extractArchiveToDisk(archive, destination.path);
      } finally {
        await input.close();
      }
    } on Object catch (e) {
      throw BackupValidationException(
        'Could not open the backup archive. It may be corrupt.\n($e)',
      );
    }

    final manifestFile = File(
      p.join(destination.path, BackupArchiveLayout.manifestPath),
    );
    if (!await manifestFile.exists()) {
      throw const BackupValidationException(
        'This backup is missing manifest.json.',
      );
    }

    final BackupManifest manifest;
    try {
      manifest = BackupManifest.decode(await manifestFile.readAsString());
    } on Object {
      throw const BackupValidationException(
        'This backup has an invalid manifest.json.',
      );
    }

    _validateManifestCompatibility(
      manifest,
      currentSchemaVersion: currentSchemaVersion,
    );

    final dbFile = File(
      p.join(destination.path, BackupArchiveLayout.databasePath),
    );
    if (!await dbFile.exists()) {
      throw const BackupValidationException(
        'This backup is missing the Study Vault database.',
      );
    }

    if (manifest.databaseSha256.isNotEmpty) {
      final actual = await sha256File(dbFile);
      if (actual != manifest.databaseSha256) {
        throw const BackupValidationException(
          'Database checksum mismatch — the backup may be corrupt.',
        );
      }
    }

    if (manifest.filesIndexSha256.isNotEmpty) {
      final materialsRoot = Directory(
        p.join(destination.path, 'backup', 'files', 'study_vault_files'),
      );
      final listed = await listFilesRecursive(materialsRoot);
      final index = buildFilesIndex([
        for (final e in listed) (relativePath: e.relativePath, size: e.size),
      ]);
      final actual = sha256Utf8(index);
      if (actual != manifest.filesIndexSha256) {
        throw const BackupValidationException(
          'Material files checksum mismatch — the backup may be corrupt '
          'or incomplete.',
        );
      }
    }

    return ValidatedBackup(
      archiveFile: archiveFile,
      manifest: manifest,
      extractedDir: destination,
    );
  }

  /// Read and validate the manifest without extracting the whole archive.
  static Future<BackupManifest> peekManifest(
    File archiveFile, {
    required int currentSchemaVersion,
  }) async {
    if (!await archiveFile.exists()) {
      throw const BackupValidationException('Backup file was not found.');
    }

    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final manifestEntry = archive.findFile(BackupArchiveLayout.manifestPath);
      if (manifestEntry == null || !manifestEntry.isFile) {
        throw const BackupValidationException(
          'This backup is missing manifest.json.',
        );
      }
      final bytes = manifestEntry.readBytes();
      if (bytes == null) {
        throw const BackupValidationException(
          'Could not read manifest.json from the backup.',
        );
      }

      final BackupManifest manifest;
      try {
        manifest = BackupManifest.decode(utf8.decode(bytes));
      } on Object {
        throw const BackupValidationException(
          'This backup has an invalid manifest.json.',
        );
      }

      _validateManifestCompatibility(
        manifest,
        currentSchemaVersion: currentSchemaVersion,
      );

      final dbEntry = archive.findFile(BackupArchiveLayout.databasePath);
      if (dbEntry == null || !dbEntry.isFile) {
        throw const BackupValidationException(
          'This backup is missing the Study Vault database.',
        );
      }

      return manifest;
    } on BackupException {
      rethrow;
    } on Object catch (e) {
      throw BackupValidationException(
        'Could not open the backup archive. It may be corrupt.\n($e)',
      );
    } finally {
      await input.close();
    }
  }

  static void _validateManifestCompatibility(
    BackupManifest manifest, {
    required int currentSchemaVersion,
  }) {
    if (manifest.format != BackupManifest.formatId) {
      throw const BackupValidationException(
        'This file is not a Study Vault backup.',
      );
    }
    if (manifest.backupFormatVersion < 1 ||
        manifest.backupFormatVersion > BackupManifest.currentFormatVersion) {
      throw BackupIncompatibleException(
        'Unsupported backup format version '
        '(${manifest.backupFormatVersion}). Update Study Vault and try again.',
      );
    }
    if (manifest.databaseSchemaVersion < 1) {
      throw const BackupValidationException(
        'Backup manifest is missing a valid database schema version.',
      );
    }
    if (manifest.databaseSchemaVersion > currentSchemaVersion) {
      throw BackupIncompatibleException(
        'This backup was created by a newer version of Study Vault '
        '(database schema ${manifest.databaseSchemaVersion}). '
        'Update Study Vault before restoring it.',
      );
    }
  }

  static Future<BackupManifest> readManifestFromExtracted(
    Directory extracted,
  ) async {
    final file = File(p.join(extracted.path, BackupArchiveLayout.manifestPath));
    return BackupManifest.decode(await file.readAsString());
  }

  static Map<String, dynamic> decodeManifestMap(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }
}
