import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/app_info.dart';
import '../database/app_database.dart';
import '../storage/study_vault_paths.dart';
import 'backup_archive.dart';
import 'backup_exceptions.dart';
import 'backup_io.dart';
import 'backup_manifest.dart';

enum BackupPhase {
  idle,
  preparingDatabase,
  collectingFiles,
  packaging,
  exporting,
  validating,
  restoring,
  success,
  error,
}

@immutable
class BackupProgress {
  const BackupProgress({
    required this.phase,
    this.message = '',
    this.materialsDone = 0,
    this.materialsTotal = 0,
    this.errorMessage,
    this.resultFileName,
    this.resultSizeBytes,
  });

  final BackupPhase phase;
  final String message;
  final int materialsDone;
  final int materialsTotal;
  final String? errorMessage;
  final String? resultFileName;
  final int? resultSizeBytes;

  static const idle = BackupProgress(phase: BackupPhase.idle);
}

/// Result of building a backup archive before export.
class BuiltBackup {
  const BuiltBackup({
    required this.archiveFile,
    required this.manifest,
    required this.suggestedFileName,
    required this.workDir,
  });

  final File archiveFile;
  final BackupManifest manifest;
  final String suggestedFileName;
  final Directory workDir;
}

/// Full Study Vault backup + restore (SQLite + material files).
class BackupService {
  BackupService({this.currentSchemaVersion = 7});

  /// Injected for tests; production uses [AppDatabase.schemaVersion].
  final int currentSchemaVersion;

  Future<LastBackupInfo?> loadLastBackupInfo() async {
    final file = await StudyVaultPaths.lastBackupMetaFile();
    if (!await file.exists()) return null;
    return LastBackupInfo.tryDecode(await file.readAsString());
  }

  Future<void> saveLastBackupInfo(LastBackupInfo info) async {
    final file = await StudyVaultPaths.lastBackupMetaFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(info.toJson()),
    );
  }

  /// Create a consistent SQLite snapshot via WAL checkpoint + file copy.
  Future<File> snapshotDatabase(AppDatabase db, File destination) async {
    await destination.parent.create(recursive: true);
    // Flush WAL into the main DB file so a plain file copy is consistent.
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

    final source = await StudyVaultPaths.databaseFile();
    if (!await source.exists()) {
      throw const BackupIoException('Study Vault database file was not found.');
    }
    await copyFileStreaming(source, destination);
    return destination;
  }

  Future<BuiltBackup> buildBackup({
    required AppDatabase db,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    void emit(BackupProgress progress) => onProgress?.call(progress);

    final workDir = await Directory.systemTemp.createTemp('sv_backup_build_');
    try {
      emit(
        const BackupProgress(
          phase: BackupPhase.preparingDatabase,
          message: 'Preparing database…',
        ),
      );

      final dbSnap = File(p.join(workDir.path, 'study_vault.sqlite'));
      await snapshotDatabase(db, dbSnap);

      emit(
        const BackupProgress(
          phase: BackupPhase.collectingFiles,
          message: 'Collecting materials…',
        ),
      );

      final materialsRoot = await StudyVaultPaths.materialsDirectory();
      final listed = await listFilesRecursive(materialsRoot);
      final index = buildFilesIndex([
        for (final e in listed) (relativePath: e.relativePath, size: e.size),
      ]);
      final totalBytes = listed.fold<int>(0, (sum, e) => sum + e.size);

      final manifest = BackupManifest(
        backupFormatVersion: BackupManifest.currentFormatVersion,
        appVersion: AppInfo.version,
        databaseSchemaVersion: currentSchemaVersion,
        createdAt: DateTime.now().toUtc(),
        platform: _platformName(),
        databaseSha256: await sha256File(dbSnap),
        filesIndexSha256: sha256Utf8(index),
        materialFileCount: listed.length,
        materialTotalBytes: totalBytes,
      );

      final manifestFile = File(p.join(workDir.path, 'manifest.json'));
      await manifestFile.writeAsString(manifest.encodePretty());

      final suggested = suggestedBackupFileName(DateTime.now());
      final archiveFile = File(p.join(workDir.path, suggested));

      emit(
        BackupProgress(
          phase: BackupPhase.packaging,
          message: 'Packaging backup…',
          materialsTotal: listed.length,
        ),
      );

      await BackupArchive.createArchive(
        outputFile: archiveFile,
        manifestFile: manifestFile,
        databaseSnapshot: dbSnap,
        materialFiles: [
          for (final e in listed) (file: e.file, relativePath: e.relativePath),
        ],
        onMaterialProgress: (done, total) {
          emit(
            BackupProgress(
              phase: BackupPhase.packaging,
              message: 'Packaging materials…',
              materialsDone: done,
              materialsTotal: total,
            ),
          );
        },
      );

      // Quick verification
      emit(
        const BackupProgress(
          phase: BackupPhase.validating,
          message: 'Verifying backup…',
        ),
      );
      final verifyDir = Directory(p.join(workDir.path, '_verify'));
      await BackupArchive.extractAndValidate(
        archiveFile,
        verifyDir,
        currentSchemaVersion: currentSchemaVersion,
      );
      await deleteIfExists(verifyDir);

      return BuiltBackup(
        archiveFile: archiveFile,
        manifest: manifest,
        suggestedFileName: suggested,
        workDir: workDir,
      );
    } catch (e) {
      await deleteIfExists(workDir);
      rethrow;
    }
  }

  /// Export [built] to a user-chosen destination (outside private storage).
  ///
  /// Linux: Save File dialog + streaming copy.
  /// Android: system share sheet (avoids loading multi-GB into memory via
  /// `saveFile(bytes: …)` which Android file_picker requires).
  ///
  /// Returns export metadata, or `null` if the user cancelled.
  Future<({String label, int sizeBytes})?> exportBuiltBackup(
    BuiltBackup built, {
    void Function(BackupProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      BackupProgress(
        phase: BackupPhase.exporting,
        message: 'Choose where to save the backup…',
        materialsDone: built.manifest.materialFileCount,
        materialsTotal: built.manifest.materialFileCount,
      ),
    );

    final sizeBytes = await built.archiveFile.length();

    try {
      if (Platform.isAndroid) {
        final result = await Share.shareXFiles(
          [
            XFile(
              built.archiveFile.path,
              mimeType: 'application/octet-stream',
              name: built.suggestedFileName,
            ),
          ],
          subject: 'Study Vault backup',
          text:
              'Save this Study Vault backup in a safe place '
              '(Downloads, Drive, USB, …). Backup files are not encrypted.',
        );
        if (result.status == ShareResultStatus.dismissed) {
          return null;
        }
        return (label: built.suggestedFileName, sizeBytes: sizeBytes);
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Study Vault backup',
        fileName: built.suggestedFileName,
        type: FileType.custom,
        allowedExtensions: const ['svbackup'],
      );
      if (path == null) return null;

      final dest = File(path.endsWith('.svbackup') ? path : '$path.svbackup');
      await copyFileStreaming(built.archiveFile, dest);
      return (label: dest.path, sizeBytes: sizeBytes);
    } finally {
      await deleteIfExists(built.workDir);
    }
  }

  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Study Vault backup',
      type: FileType.custom,
      allowedExtensions: const ['svbackup'],
      withData: false,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) {
      throw const BackupIoException(
        'Could not access the selected backup file.',
      );
    }
    return File(path);
  }

  /// Validate a backup file and return its manifest (temp extract cleaned up).
  Future<BackupManifest> inspectBackup(File archive) {
    return BackupArchive.peekManifest(
      archive,
      currentSchemaVersion: currentSchemaVersion,
    );
  }

  /// Restore [archive] into the live Study Vault data directory.
  ///
  /// [closeDatabase] must close all open SQLite connections first.
  /// [reopenDatabase] opens a fresh connection afterwards (runs migrations).
  Future<BackupManifest> restoreBackup({
    required File archive,
    required Future<void> Function() closeDatabase,
    required Future<void> Function() reopenDatabase,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    void emit(BackupProgress progress) => onProgress?.call(progress);

    emit(
      const BackupProgress(
        phase: BackupPhase.validating,
        message: 'Validating backup…',
      ),
    );

    final docs = await StudyVaultPaths.documentsDirectory();
    final workRoot = Directory(
      p.join(
        docs.path,
        '.sv_restore_work_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    final extractDir = Directory(p.join(workRoot.path, 'incoming'));
    final rollbackDir = Directory(p.join(workRoot.path, 'rollback'));

    try {
      final validated = await BackupArchive.extractAndValidate(
        archive,
        extractDir,
        currentSchemaVersion: currentSchemaVersion,
      );

      emit(
        const BackupProgress(
          phase: BackupPhase.restoring,
          message: 'Installing backup…',
        ),
      );

      await closeDatabase();

      final liveDb = await StudyVaultPaths.databaseFile();
      final liveMaterials = await StudyVaultPaths.materialsDirectory();
      await rollbackDir.create(recursive: true);

      // Move current data aside for rollback.
      if (await liveDb.exists()) {
        await liveDb.rename(p.join(rollbackDir.path, 'study_vault.sqlite'));
      }
      for (final side in await StudyVaultPaths.databaseSidecarFiles()) {
        if (await side.exists()) {
          await side.delete();
        }
      }
      if (await liveMaterials.exists()) {
        await liveMaterials.rename(
          p.join(rollbackDir.path, 'study_vault_files'),
        );
      }

      try {
        final incomingDb = File(
          p.join(extractDir.path, BackupArchiveLayout.databasePath),
        );
        await copyFileStreaming(incomingDb, liveDb);

        final incomingMaterials = Directory(
          p.join(extractDir.path, 'backup', 'files', 'study_vault_files'),
        );
        final docs = await StudyVaultPaths.documentsDirectory();
        final targetMaterials = Directory(
          p.join(docs.path, StudyVaultPaths.materialsDirName),
        );
        await deleteIfExists(targetMaterials);
        if (await incomingMaterials.exists()) {
          await copyDirectoryStreaming(incomingMaterials, targetMaterials);
        } else {
          await targetMaterials.create(recursive: true);
        }

        await reopenDatabase();

        // Lightweight open verification — reopen already ran migrations.
        emit(
          const BackupProgress(
            phase: BackupPhase.validating,
            message: 'Verifying restored data…',
          ),
        );
      } catch (e) {
        // Roll back live data.
        await _restoreRollback(
          rollbackDir: rollbackDir,
          liveDb: liveDb,
          liveMaterials: liveMaterials,
        );
        try {
          await reopenDatabase();
        } on Object {
          // Best effort — surface original error.
        }
        throw RestoreFailedException(
          'Restore failed and previous data was rolled back.\n($e)',
        );
      }

      await deleteIfExists(rollbackDir);
      return validated.manifest;
    } finally {
      await deleteIfExists(workRoot);
    }
  }

  Future<void> _restoreRollback({
    required Directory rollbackDir,
    required File liveDb,
    required Directory liveMaterials,
  }) async {
    await deleteIfExists(liveDb);
    for (final side in await StudyVaultPaths.databaseSidecarFiles()) {
      await deleteIfExists(side);
    }
    await deleteIfExists(liveMaterials);

    final rbDb = File(p.join(rollbackDir.path, 'study_vault.sqlite'));
    if (await rbDb.exists()) {
      await rbDb.rename(liveDb.path);
    }
    final rbFiles = Directory(p.join(rollbackDir.path, 'study_vault_files'));
    if (await rbFiles.exists()) {
      await rbFiles.rename(liveMaterials.path);
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }
}
