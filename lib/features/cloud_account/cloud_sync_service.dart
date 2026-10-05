import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/app_info.dart';
import '../../../core/backup/backup_archive.dart';
import '../../../core/backup/backup_io.dart';
import '../../../core/backup/backup_manifest.dart';
import '../../../core/database/app_database.dart';
import 'cloud_api.dart';
import 'cloud_sync_merge.dart';
import 'cloud_sync_schema.dart';

class _CloudValidationDatabase extends AppDatabase {
  _CloudValidationDatabase() : super.forTesting(NativeDatabase.memory());
}

class CloudSyncService {
  CloudSyncService({
    required this.db,
    required this.remote,
    required this.filesRoot,
    required this.recoveryRoot,
    required this.serverId,
  });

  final AppDatabase db;
  final CloudSyncRemote remote;
  final Directory filesRoot;
  final Directory recoveryRoot;
  final String serverId;
  final Uuid _uuid = const Uuid();
  bool _running = false;

  Future<T> _remote<T>(
    Future<T> Function() action,
    void Function(String) progress,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on CloudApiException catch (error) {
        if (error.status != 429 || attempt >= 3) rethrow;
        progress('Server is busy; waiting before retrying safely…');
        await Future<void>.delayed(
          error.retryAfter ?? const Duration(seconds: 60),
        );
      }
    }
  }

  Future<Map<String, dynamic>> info() async {
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS local_cloud_sync ('
      'id INTEGER PRIMARY KEY CHECK(id=1), account TEXT, baseline TEXT NOT NULL DEFAULT \'{}\', '
      'pending TEXT, last_sync TEXT, backup_path TEXT)',
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO local_cloud_sync(id) VALUES(1)',
    );
    return (await db
            .customSelect('SELECT * FROM local_cloud_sync WHERE id=1')
            .getSingle())
        .data;
  }

  Future<CloudRows> _databaseRows(AppDatabase source) async {
    final result = <String, Map<String, dynamic>>{};
    for (final table in source.allTables) {
      final rows = await source
          .customSelect('SELECT * FROM "${table.actualTableName}" ORDER BY id')
          .get();
      for (final row in rows) {
        result[cloudKey(table.actualTableName, row.data['id'] as String)] =
            Map.of(row.data);
      }
    }
    return result;
  }

  Future<File> _safeFile(String relative) async {
    final parts = relative.split('/');
    if (relative.isEmpty ||
        relative.startsWith('/') ||
        relative.contains('\\') ||
        relative.contains(':') ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const CloudSyncFailure('Unsafe material path was rejected.');
    }
    var current = p.absolute(filesRoot.path);
    for (final part in ['', ...parts]) {
      if (part.isNotEmpty) current = p.join(current, part);
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const CloudSyncFailure('Symbolic links cannot be synchronized.');
      }
    }
    return File(current);
  }

  Future<CloudRows> _fileRows() async {
    final rows = <String, Map<String, dynamic>>{};
    if (!await filesRoot.exists()) return rows;
    await _safeFile('path-check');
    await for (final entity in filesRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw const CloudSyncFailure(
          'Remove symbolic links from the material folder before syncing.',
        );
      }
      if (entity is! File) continue;
      final relative = p.posix.fromUri(
        p.toUri(p.relative(entity.path, from: filesRoot.path)),
      );
      final file = await _safeFile(relative);
      final before = await file.stat();
      final digest = await sha256File(file);
      final after = await file.stat();
      if (before.size != after.size || before.modified != after.modified) {
        throw const CloudSyncFailure(
          'A file changed during preparation. Please sync again.',
        );
      }
      rows[cloudKey('material_files', relative)] = {
        'id': relative,
        'sha256': digest,
        'bytes': after.size,
      };
    }
    return rows;
  }

  CloudRows _withMissingDownloads(
    CloudRows records,
    CloudRows actualFiles,
    CloudRows known,
  ) {
    final rows = <String, Map<String, dynamic>>{...records, ...actualFiles};
    for (final entry in records.entries) {
      final path = cloudFilePath(cloudTable(entry.key), entry.value);
      if (path == null) continue;
      final key = cloudKey('material_files', path);
      if (!rows.containsKey(key) && known.containsKey(key)) {
        rows[key] = Map.of(known[key]!);
      }
    }
    return rows;
  }

  Future<void> _replaceRows(AppDatabase target, CloudRows wanted) async {
    final current = await _databaseRows(target);
    await target.customStatement('PRAGMA defer_foreign_keys = ON');
    for (final table in target.allTables.toList().reversed) {
      for (final entry in current.entries.where(
        (e) => cloudTable(e.key) == table.actualTableName,
      )) {
        if (!cloudEqual(entry.value, wanted[entry.key])) {
          await target.customStatement(
            'DELETE FROM "${table.actualTableName}" WHERE id=?',
            [cloudId(entry.key)],
          );
        }
      }
    }
    for (final table in target.allTables) {
      for (final entry in wanted.entries.where(
        (e) => cloudTable(e.key) == table.actualTableName,
      )) {
        final names = entry.value.keys.toList();
        final columns = names.map((n) => '"$n"').join(',');
        final updates = names
            .where((n) => n != 'id')
            .map((n) => '"$n"=excluded."$n"')
            .join(',');
        await target.customStatement(
          'INSERT INTO "${table.actualTableName}" ($columns) '
          'VALUES (${List.filled(names.length, '?').join(',')}) ON CONFLICT(id) DO UPDATE SET $updates',
          names.map((n) => entry.value[n]).toList(),
        );
      }
    }
    if ((await target.customSelect('PRAGMA foreign_key_check').get())
        .isNotEmpty) {
      throw const CloudSyncFailure(
        'Related records could not be applied safely.',
      );
    }
    final expected = Map.of(wanted)
      ..removeWhere((key, _) => cloudTable(key) == 'material_files');
    if (!cloudEqual(await _databaseRows(target), expected)) {
      throw const CloudSyncFailure(
        'Database validation failed; local changes were rolled back.',
      );
    }
  }

  Future<void> _validateDatabase(CloudRows rows) async {
    final scratch = _CloudValidationDatabase();
    try {
      await scratch.transaction(() => _replaceRows(scratch, rows));
    } finally {
      await scratch.close();
    }
  }

  Future<String> _backup(Directory work, void Function(String) progress) async {
    progress('Creating a local recovery backup…');
    await work.create(recursive: true);
    final database = File(p.join(work.path, 'database.sqlite'));
    await db.customStatement('VACUUM INTO ?', [database.path]);
    final files = await listFilesRecursive(filesRoot);
    final manifest = BackupManifest(
      backupFormatVersion: BackupManifest.currentFormatVersion,
      appVersion: AppInfo.version,
      databaseSchemaVersion: db.schemaVersion,
      createdAt: DateTime.now().toUtc(),
      platform: Platform.operatingSystem,
      databaseSha256: await sha256File(database),
      filesIndexSha256: sha256Utf8(
        buildFilesIndex([
          for (final file in files)
            (relativePath: file.relativePath, size: file.size),
        ]),
      ),
      materialFileCount: files.length,
      materialTotalBytes: files.fold(0, (sum, file) => sum + file.size),
    );
    final manifestFile = File(p.join(work.path, 'manifest.json'));
    await manifestFile.writeAsString(manifest.encodePretty());
    final backup = File(p.join(work.path, 'Before-sync.svbackup'));
    await BackupArchive.createArchive(
      outputFile: backup,
      manifestFile: manifestFile,
      databaseSnapshot: database,
      materialFiles: [
        for (final file in files)
          (file: file.file, relativePath: file.relativePath),
      ],
      onMaterialProgress: (done, total) =>
          progress('Recovery backup: $done / $total files'),
    );
    await BackupArchive.peekManifest(
      backup,
      currentSchemaVersion: db.schemaVersion,
    );
    await db.customStatement(
      'UPDATE local_cloud_sync SET backup_path=? WHERE id=1',
      [backup.path],
    );
    return backup.path;
  }

  Future<CloudSyncOutcome> sync({
    required String token,
    required String accountId,
    bool consent = false,
    CloudConflictChoice? choice,
    String? resolutionToken,
    void Function(String)? onProgress,
  }) async {
    if (_running) {
      throw const CloudSyncFailure('A synchronization is already running.');
    }
    _running = true;
    final progress = onProgress ?? (_) {};
    Directory? work;
    final fileUndo = <({File target, File? previous})>[];
    try {
      var state = await info();
      final binding = '$serverId|$accountId';
      if (state['account'] != null && state['account'] != binding) {
        throw const CloudSyncFailure(
          'This local library is linked to a different account or server. It will not be uploaded.',
        );
      }
      if (state['account'] == null) {
        if (!consent) {
          throw const CloudSyncFailure(
            'Confirm the first synchronization before uploading your library.',
          );
        }
        await db.customStatement(
          'UPDATE local_cloud_sync SET account=? WHERE id=1',
          [binding],
        );
      }
      if (state['pending'] != null) {
        progress('Checking the previous interrupted synchronization…');
        try {
          await _remote(
            () => remote.commit(
              token,
              jsonDecode(state['pending'] as String) as Map<String, dynamic>,
            ),
            progress,
          );
        } on CloudApiException catch (error) {
          if (error.code != 'head_changed') rethrow;
        }
        await db.customStatement(
          'UPDATE local_cloud_sync SET pending=NULL WHERE id=1',
        );
      }
      state = await info();
      final base = cloudRowsFromJson(jsonDecode(state['baseline'] as String));
      progress('Reading the cloud library…');
      final cloud = await _remote(() => remote.snapshot(token), progress);
      final schema = await CloudSyncSchema.load(db);
      for (final entry in cloud.rows.entries) {
        schema.validateRow(entry.key, entry.value);
      }
      schema.validate(cloud.rows);
      progress('Checking offline edits and local files…');
      final databaseRows = await db.transaction(() => _databaseRows(db));
      final files = await _fileRows();
      final local = _withMissingDownloads(databaseRows, files, {
        ...cloud.rows,
        ...base,
      });
      final originalPlan = CloudMerge.plan(
        schema: schema,
        base: base,
        device: local,
        server: cloud.rows,
      );
      if (originalPlan.conflicts.isNotEmpty &&
          (choice == null || resolutionToken != originalPlan.token)) {
        return CloudSyncOutcome(
          conflicts: originalPlan.conflicts,
          resolutionToken: originalPlan.token,
          backupPath: state['backup_path'] as String?,
          message:
              'Review ${originalPlan.conflicts.length} conflicting items. Neither version has been overwritten.',
        );
      }
      final plan = choice == null
          ? originalPlan
          : CloudMerge.plan(
              schema: schema,
              base: base,
              device: local,
              server: cloud.rows,
              choice: choice,
            );
      final desired = plan.rows;
      schema.validate(desired);
      await _validateDatabase(desired);
      final mutations = <Map<String, dynamic>>[];
      for (final key in {...cloud.rows.keys, ...desired.keys}) {
        if (cloudEqual(cloud.rows[key], desired[key])) continue;
        mutations.add({
          'table': cloudTable(key),
          'id': cloudId(key),
          'data': desired[key],
          'baseRevision': cloud.revisions[key] ?? 0,
          'mutationId': _uuid.v4(),
        });
      }
      final desiredFiles = Map.of(desired)
        ..removeWhere((key, _) => cloudTable(key) != 'material_files');
      final changed =
          mutations.isNotEmpty ||
          !cloudEqual(local, desired) ||
          !cloudEqual(files, desiredFiles);
      String? backupPath = state['backup_path'] as String?;
      final downloads = <String, File>{};
      if (changed) {
        work = Directory(
          p.join(
            recoveryRoot.path,
            '${DateTime.now().toUtc().millisecondsSinceEpoch}-${_uuid.v4()}',
          ),
        );
        backupPath = await _backup(work, progress);
        await File(
          p.join(work.path, 'cloud-before.json'),
        ).writeAsString(cloudCanonical(cloud.rows));
        final knownDigests = {
          for (final entry in cloud.rows.entries)
            if (cloudTable(entry.key) == 'material_files')
              entry.value['sha256'] as String,
        };
        var done = 0;
        for (final entry in desiredFiles.entries) {
          final data = entry.value;
          final digest = data['sha256'] as String;
          progress(
            'Checking and transferring files: ${++done} / ${desiredFiles.length}',
          );
          if (!knownDigests.contains(digest) &&
              !await _remote(() => remote.hasFile(token, digest), progress)) {
            final source = await _safeFile(cloudId(entry.key));
            if (!await source.exists() || await sha256File(source) != digest) {
              throw const CloudSyncFailure(
                'A required source file is missing or changed. Restore it and sync again.',
              );
            }
            await _remote(
              () => remote.uploadFile(token, digest, source),
              progress,
            );
            knownDigests.add(digest);
          }
          if (!cloudEqual(files[entry.key], data)) {
            final target = File(p.join(work.path, 'downloads', _uuid.v4()));
            await _remote(
              () => remote.downloadFile(
                token,
                digest,
                data['bytes'] as int,
                target,
              ),
              progress,
            );
            if (await target.length() != data['bytes'] ||
                await sha256File(target) != digest) {
              throw const CloudSyncFailure(
                'A downloaded file failed verification.',
              );
            }
            downloads[entry.key] = target;
          }
        }
      }
      if (!cloudEqual(await _fileRows(), files)) {
        throw const CloudSyncFailure(
          'Local files changed while syncing. No local files were replaced; please retry.',
        );
      }
      final request = {
        'schemaVersion': db.schemaVersion,
        'operationId': _uuid.v4(),
        'expectedHead': cloud.head,
        'mutations': mutations,
      };
      if (mutations.isNotEmpty) {
        await db.customStatement(
          'UPDATE local_cloud_sync SET pending=? WHERE id=1',
          [jsonEncode(request)],
        );
      }
      final syncedAt = DateTime.now().toUtc();
      var remoteAttempted = false;
      try {
        await db.transaction(() async {
          if (!cloudEqual(await _databaseRows(db), databaseRows)) {
            throw const CloudSyncFailure(
              'Local records changed during sync. Please retry; new edits were preserved.',
            );
          }
          if (mutations.isNotEmpty) {
            progress('Publishing the library atomically…');
            remoteAttempted = true;
            await _remote(() => remote.commit(token, request), progress);
          }
          if (!cloudEqual(await _fileRows(), files)) {
            throw const CloudSyncFailure(
              'A file changed while the server was committing. Its local copy was preserved; sync again.',
            );
          }
          progress('Applying verified changes locally…');
          for (final key in {...files.keys, ...desiredFiles.keys}) {
            if (cloudEqual(files[key], desiredFiles[key])) continue;
            final target = await _safeFile(cloudId(key));
            File? previous;
            if (await target.exists()) {
              previous = File(p.join(work!.path, 'previous-files', _uuid.v4()));
              await previous.parent.create(recursive: true);
              await target.rename(previous.path);
            }
            fileUndo.add((target: target, previous: previous));
            final incoming = downloads[key];
            if (incoming != null) {
              await target.parent.create(recursive: true);
              await incoming.rename(target.path);
            }
          }
          if (!cloudEqual(local, desired)) await _replaceRows(db, desired);
          await db.customStatement(
            'UPDATE local_cloud_sync SET baseline=?,pending=NULL,last_sync=? WHERE id=1',
            [cloudCanonical(desired), syncedAt.toIso8601String()],
          );
        });
      } catch (error) {
        if (!remoteAttempted ||
            error is CloudApiException &&
                (error.code == 'head_changed' ||
                    [
                      400,
                      401,
                      403,
                      404,
                      413,
                      415,
                      422,
                      429,
                    ].contains(error.status))) {
          await db.customStatement(
            'UPDATE local_cloud_sync SET pending=NULL WHERE id=1',
          );
        }
        for (final undo in fileUndo.reversed) {
          if (await undo.target.exists()) {
            await undo.target.rename(
              p.join(work!.path, 'uncommitted-${_uuid.v4()}'),
            );
          }
          if (undo.previous != null && await undo.previous!.exists()) {
            await undo.target.parent.create(recursive: true);
            await undo.previous!.rename(undo.target.path);
          }
        }
        rethrow;
      }
      db.notifyUpdates({
        for (final table in db.allTables) TableUpdate.onTable(table),
      });
      return CloudSyncOutcome(
        lastSync: syncedAt,
        backupPath: backupPath,
        message: changed
            ? 'Library synchronized. Your recovery backup was kept.'
            : 'Everything is already synchronized.',
      );
    } finally {
      _running = false;
    }
  }
}
