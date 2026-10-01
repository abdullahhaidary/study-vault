import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/backup/backup_archive.dart';
import 'package:study_vault/core/backup/backup_io.dart';
import 'package:study_vault/core/backup/backup_manifest.dart';

/// Filesystem restore-path simulation without opening Drift.
void main() {
  test(
    'restore copies database and materials; rollback restores previous',
    () async {
      final root = await Directory.systemTemp.createTemp('sv_restore_sim_');
      addTearDown(() async => deleteIfExists(root));

      final liveDb = File(p.join(root.path, 'live', 'study_vault.sqlite'));
      final liveFiles = Directory(
        p.join(root.path, 'live', 'study_vault_files'),
      );
      await liveDb.parent.create(recursive: true);
      await liveDb.writeAsString('OLD-DB');
      final oldMat = File(p.join(liveFiles.path, 'lessons', '1', 'a.pdf'));
      await oldMat.parent.create(recursive: true);
      await oldMat.writeAsString('old-pdf');

      final incoming = Directory(p.join(root.path, 'incoming'));
      final newDb = File(
        p.join(incoming.path, BackupArchiveLayout.databasePath),
      );
      await newDb.parent.create(recursive: true);
      await newDb.writeAsString('NEW-DB');
      final newMat = File(
        p.join(incoming.path, 'backup/files/study_vault_files/lessons/2/b.pdf'),
      );
      await newMat.parent.create(recursive: true);
      await newMat.writeAsString('new-pdf');

      final rollback = Directory(p.join(root.path, 'rollback'));
      await rollback.create();

      await liveDb.rename(p.join(rollback.path, 'study_vault.sqlite'));
      await liveFiles.rename(p.join(rollback.path, 'study_vault_files'));
      await copyFileStreaming(newDb, liveDb);
      await copyDirectoryStreaming(
        Directory(p.join(incoming.path, 'backup/files/study_vault_files')),
        liveFiles,
      );

      expect(await liveDb.readAsString(), 'NEW-DB');
      expect(
        await File(
          p.join(liveFiles.path, 'lessons', '2', 'b.pdf'),
        ).readAsString(),
        'new-pdf',
      );
      expect(
        await File(p.join(liveFiles.path, 'lessons', '1', 'a.pdf')).exists(),
        isFalse,
      );

      await deleteIfExists(liveDb);
      await deleteIfExists(liveFiles);
      await File(
        p.join(rollback.path, 'study_vault.sqlite'),
      ).rename(liveDb.path);
      await Directory(
        p.join(rollback.path, 'study_vault_files'),
      ).rename(liveFiles.path);

      expect(await liveDb.readAsString(), 'OLD-DB');
      expect(
        await File(
          p.join(liveFiles.path, 'lessons', '1', 'a.pdf'),
        ).readAsString(),
        'old-pdf',
      );
    },
  );

  test('streaming copy does not require readAsBytes of whole file', () async {
    final root = await Directory.systemTemp.createTemp('sv_stream_');
    addTearDown(() async => deleteIfExists(root));
    final src = File(p.join(root.path, 'src.bin'));
    final sink = src.openWrite();
    final chunk = List<int>.generate(1024, (i) => i % 256);
    for (var i = 0; i < 1024; i++) {
      sink.add(chunk);
    }
    await sink.close();

    final dest = File(p.join(root.path, 'dest.bin'));
    await copyFileStreaming(src, dest);
    expect(await dest.length(), await src.length());
    expect(await sha256File(dest), await sha256File(src));
  });

  test('LastBackupInfo roundtrip', () {
    final info = LastBackupInfo(
      fileName: 'StudyVault-2026-10-01-2035.svbackup',
      createdAt: DateTime.utc(2026, 10, 1, 20, 35),
      sizeBytes: 426000000,
      materialFileCount: 245,
    );
    final decoded = LastBackupInfo.tryDecode(jsonEncode(info.toJson()));
    expect(decoded, isNotNull);
    expect(decoded!.fileName, info.fileName);
    expect(decoded.sizeBytes, 426000000);
    expect(decoded.materialFileCount, 245);
  });
}
