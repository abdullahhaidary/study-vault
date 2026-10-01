import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/backup/backup_archive.dart';
import 'package:study_vault/core/backup/backup_exceptions.dart';
import 'package:study_vault/core/backup/backup_io.dart';
import 'package:study_vault/core/backup/backup_manifest.dart';

void main() {
  group('BackupManifest', () {
    test('serializes and deserializes', () {
      final original = BackupManifest(
        backupFormatVersion: 1,
        appVersion: '1.0.0+1',
        databaseSchemaVersion: 7,
        createdAt: DateTime.utc(2026, 10, 1, 20, 35),
        platform: 'linux',
        databaseSha256: 'abc',
        filesIndexSha256: 'def',
        materialFileCount: 2,
        materialTotalBytes: 99,
      );

      final roundTrip = BackupManifest.decode(original.encodePretty());
      expect(roundTrip.format, BackupManifest.formatId);
      expect(roundTrip.backupFormatVersion, 1);
      expect(roundTrip.appVersion, '1.0.0+1');
      expect(roundTrip.databaseSchemaVersion, 7);
      expect(roundTrip.platform, 'linux');
      expect(roundTrip.databaseSha256, 'abc');
      expect(roundTrip.filesIndexSha256, 'def');
      expect(roundTrip.materialFileCount, 2);
      expect(roundTrip.materialTotalBytes, 99);
    });
  });

  group('backup helpers', () {
    test('suggestedBackupFileName format', () {
      final name = suggestedBackupFileName(DateTime(2026, 10, 1, 20, 35));
      expect(name, 'StudyVault-2026-10-01-2035.svbackup');
    });

    test('files index is stable and sorted', () {
      final index = buildFilesIndex([
        (relativePath: 'lessons/b/a.pdf', size: 2),
        (relativePath: 'lessons/a/z.pdf', size: 1),
      ]);
      expect(index, 'lessons/a/z.pdf\t1\nlessons/b/a.pdf\t2\n');
      expect(sha256Utf8(index), isNotEmpty);
    });

    test('unicode and spaces in relative paths', () async {
      final root = await Directory.systemTemp.createTemp('sv_paths_');
      addTearDown(() async => deleteIfExists(root));
      final file = File(p.join(root.path, 'lessons', 'id 1', 'note 你好.pdf'));
      await file.parent.create(recursive: true);
      await file.writeAsString('x');
      final listed = await listFilesRecursive(root);
      expect(listed, hasLength(1));
      expect(listed.single.relativePath, 'lessons/id 1/note 你好.pdf');
    });
  });

  group('BackupArchive', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('sv_archive_');
    });

    tearDown(() async {
      await deleteIfExists(temp);
    });

    Future<File> buildSampleArchive({
      int schemaVersion = 7,
      String? dbContent,
      List<({String rel, String content})> materials = const [],
      bool omitManifest = false,
      bool omitDatabase = false,
      String format = BackupManifest.formatId,
      int formatVersion = 1,
    }) async {
      final work = Directory(p.join(temp.path, 'work'));
      await work.create();
      final dbFile = File(p.join(work.path, 'db.sqlite'));
      await dbFile.writeAsString(dbContent ?? 'sqlite-bytes');
      final materialFiles = <({File file, String relativePath})>[];
      for (final m in materials) {
        final f = File(p.join(work.path, 'mat', m.rel));
        await f.parent.create(recursive: true);
        await f.writeAsString(m.content);
        materialFiles.add((file: f, relativePath: m.rel));
      }

      final listed = [
        for (final m in materialFiles)
          (relativePath: m.relativePath, size: await m.file.length()),
      ];
      final index = buildFilesIndex(listed);
      final manifest = BackupManifest(
        format: format,
        backupFormatVersion: formatVersion,
        appVersion: '1.0.0+1',
        databaseSchemaVersion: schemaVersion,
        createdAt: DateTime.utc(2026, 10, 1),
        platform: 'linux',
        databaseSha256: await sha256File(dbFile),
        filesIndexSha256: sha256Utf8(index),
        materialFileCount: listed.length,
        materialTotalBytes: listed.fold(0, (a, b) => a + b.size),
      );
      final manifestFile = File(p.join(work.path, 'manifest.json'));
      if (!omitManifest) {
        await manifestFile.writeAsString(manifest.encodePretty());
      } else {
        await manifestFile.writeAsString('{}');
      }

      final out = File(p.join(temp.path, 'sample.svbackup'));
      final encoderFiles = <({File file, String relativePath})>[
        ...materialFiles,
      ];
      // Create archive manually for omit cases
      if (omitManifest || omitDatabase) {
        final encoder = ZipFileEncoder();
        encoder.create(out.path);
        if (!omitManifest) {
          await encoder.addFile(manifestFile, BackupArchiveLayout.manifestPath);
        }
        if (!omitDatabase) {
          await encoder.addFile(dbFile, BackupArchiveLayout.databasePath);
        }
        for (final e in encoderFiles) {
          await encoder.addFile(
            e.file,
            '${BackupArchiveLayout.filesPrefix}${e.relativePath}',
          );
        }
        await encoder.close();
      } else {
        await BackupArchive.createArchive(
          outputFile: out,
          manifestFile: manifestFile,
          databaseSnapshot: dbFile,
          materialFiles: encoderFiles,
        );
      }
      return out;
    }

    test(
      'backup contains database and materials with relative paths',
      () async {
        final archive = await buildSampleArchive(
          materials: [
            (rel: 'lessons/abc/file.pdf', content: 'pdf'),
            (rel: 'lessons/abc/nested/img.png', content: 'png'),
          ],
        );

        final extract = Directory(p.join(temp.path, 'out'));
        final validated = await BackupArchive.extractAndValidate(
          archive,
          extract,
          currentSchemaVersion: 7,
        );

        expect(validated.manifest.materialFileCount, 2);
        expect(
          await File(
            p.join(extract.path, BackupArchiveLayout.databasePath),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              extract.path,
              'backup/files/study_vault_files/lessons/abc/file.pdf',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              extract.path,
              'backup/files/study_vault_files/lessons/abc/nested/img.png',
            ),
          ).exists(),
          isTrue,
        );
      },
    );

    test('empty materials directory works', () async {
      final archive = await buildSampleArchive();
      final extract = Directory(p.join(temp.path, 'empty_out'));
      final validated = await BackupArchive.extractAndValidate(
        archive,
        extract,
        currentSchemaVersion: 7,
      );
      expect(validated.manifest.materialFileCount, 0);
    });

    test('peekManifest validates without full extract', () async {
      final archive = await buildSampleArchive(schemaVersion: 5);
      final manifest = await BackupArchive.peekManifest(
        archive,
        currentSchemaVersion: 7,
      );
      expect(manifest.databaseSchemaVersion, 5);
    });

    test('missing manifest rejected', () async {
      final out = File(p.join(temp.path, 'bad.svbackup'));
      final encoder = ZipFileEncoder();
      encoder.create(out.path);
      final db = File(p.join(temp.path, 'only.db'))..writeAsStringSync('x');
      await encoder.addFile(db, BackupArchiveLayout.databasePath);
      await encoder.close();

      expect(
        () => BackupArchive.peekManifest(out, currentSchemaVersion: 7),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('missing database rejected', () async {
      final archive = await buildSampleArchive(omitDatabase: true);
      expect(
        () => BackupArchive.peekManifest(archive, currentSchemaVersion: 7),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('unsupported backup format rejected', () async {
      final archive = await buildSampleArchive(formatVersion: 99);
      expect(
        () => BackupArchive.peekManifest(archive, currentSchemaVersion: 7),
        throwsA(isA<BackupIncompatibleException>()),
      );
    });

    test('newer DB schema rejected safely', () async {
      final archive = await buildSampleArchive(schemaVersion: 99);
      expect(
        () => BackupArchive.peekManifest(archive, currentSchemaVersion: 7),
        throwsA(isA<BackupIncompatibleException>()),
      );
    });

    test('older supported DB schema accepted', () async {
      final archive = await buildSampleArchive(schemaVersion: 4);
      final manifest = await BackupArchive.peekManifest(
        archive,
        currentSchemaVersion: 7,
      );
      expect(manifest.databaseSchemaVersion, 4);
    });

    test('corrupt checksum rejected on extract', () async {
      final archive = await buildSampleArchive();
      // Tamper by rebuilding zip with wrong checksum in manifest
      final work = Directory(p.join(temp.path, 'tamper'));
      await work.create();
      final input = InputFileStream(archive.path);
      try {
        final decoded = ZipDecoder().decodeStream(input);
        await extractArchiveToDisk(decoded, work.path);
      } finally {
        await input.close();
      }
      final manifestFile = File(
        p.join(work.path, BackupArchiveLayout.manifestPath),
      );
      final map =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      (map['checksums'] as Map)['databaseSha256'] = 'deadbeef';
      await manifestFile.writeAsString(jsonEncode(map));

      final bad = File(p.join(temp.path, 'tampered.svbackup'));
      final encoder = ZipFileEncoder();
      await encoder.zipDirectory(work, filename: bad.path);

      expect(
        () => BackupArchive.extractAndValidate(
          bad,
          Directory(p.join(temp.path, 'bad_out')),
          currentSchemaVersion: 7,
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('invalid archive rejected', () async {
      final junk = File(p.join(temp.path, 'junk.svbackup'));
      await junk.writeAsString('not-a-zip');
      expect(
        () => BackupArchive.peekManifest(junk, currentSchemaVersion: 7),
        throwsA(isA<BackupValidationException>()),
      );
    });
  });
}
