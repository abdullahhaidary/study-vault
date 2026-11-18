import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/backup/backup_io.dart';
import '../../../core/database/app_database.dart';
import 'cloud_api.dart';
import 'cloud_sync_merge.dart';
import 'cloud_sync_local.dart';
import 'cloud_sync_schema.dart';

class CloudSyncService {
  CloudSyncService({
    required this.db,
    required this.remote,
    required this.filesRoot,
    required this.recoveryRoot,
    required this.serverId,
    this.hashFile = sha256File,
  });

  final AppDatabase db;
  final CloudSyncRemote remote;
  final Directory filesRoot;
  final Directory recoveryRoot;
  final String serverId;
  final Future<String> Function(File) hashFile;
  final Uuid _uuid = const Uuid();
  bool _running = false;
  late final _local = CloudSyncLocal(db);
  late final _schema = CloudSyncSchema.load(db);

  void _checkReceipt(CloudCommit receipt, Map<String, dynamic> request) {
    final mutations = request['mutations'] as List;
    final expectedHead = request['expectedHead'] as int;
    if (receipt.accepted.length != mutations.length ||
        receipt.head < expectedHead ||
        mutations.any(
          (m) =>
              receipt.accepted[m['mutationId']] == null ||
              receipt.accepted[m['mutationId']]! <= expectedHead ||
              receipt.accepted[m['mutationId']]! > receipt.head,
        )) {
      throw const CloudSyncFailure(
        'Invalid server commit receipt. Retry to check the accepted operation.',
      );
    }
  }

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

  Future<Map<String, dynamic>> info({bool includeBaseline = true}) async {
    await _local.initialize();
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS local_cloud_sync ('
      'id INTEGER PRIMARY KEY CHECK(id=1), account TEXT, baseline TEXT NOT NULL DEFAULT \'{}\', '
      'pending TEXT, last_sync TEXT, backup_path TEXT)',
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO local_cloud_sync(id) VALUES(1)',
    );
    return (await db
            .customSelect(
              'SELECT ${includeBaseline ? '*' : 'id,account,pending,last_sync,backup_path'} FROM local_cloud_sync WHERE id=1',
            )
            .getSingle())
        .data;
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
    final cached = {
      for (final row
          in await db
              .customSelect('SELECT * FROM local_cloud_sync_files')
              .get())
        row.data['path'] as String: row.data,
    };
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
      final signature =
          '${before.size}:${before.modified.microsecondsSinceEpoch}:${before.changed.microsecondsSinceEpoch}';
      final previous = cached[relative];
      final digest = previous?['signature'] == signature
          ? previous!['digest'] as String
          : await hashFile(file);
      final after = await file.stat();
      if (before.size != after.size ||
          before.modified != after.modified ||
          before.changed != after.changed) {
        throw const CloudSyncFailure(
          'A file changed during preparation. Please sync again.',
        );
      }
      if (previous?['signature'] != signature) {
        await db.customStatement(
          'INSERT OR REPLACE INTO local_cloud_sync_files(path,signature,digest) VALUES(?,?,?)',
          [relative, signature, digest],
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

  Future<void> _replaceRows(
    AppDatabase target,
    CloudRows wanted,
    CloudRows current,
    CloudSyncSchema schema,
  ) async {
    // Release only changed unique references, rather than rebuilding all rows.
    // Include their dependents so FK cascades cannot silently remove a retained
    // translation or other child when a version/reference is reassigned.
    final reset = <String>{};
    final children = <String, List<String>>{};
    for (final entry in current.entries) {
      final spec = schema.tables[cloudTable(entry.key)]!;
      final next = wanted[entry.key];
      if (next == null ||
          (spec['unique'] as List).any(
            (columns) => (columns as List).any(
              (column) => entry.value[column] != next[column],
            ),
          )) {
        reset.add(entry.key);
      }
      for (final foreign in spec['foreignKeys'] as List) {
        final id = entry.value[foreign['column']];
        if (id != null) {
          children
              .putIfAbsent(
                cloudKey(foreign['table'] as String, id as String),
                () => [],
              )
              .add(entry.key);
        }
      }
    }
    final queue = reset.toList();
    for (var i = 0; i < queue.length; i++) {
      for (final child in children[queue[i]] ?? <String>[]) {
        if (reset.add(child)) queue.add(child);
      }
    }
    await target.customStatement('PRAGMA defer_foreign_keys = ON');
    for (final table in target.allTables.toList().reversed) {
      for (final entry in current.entries.where(
        (e) => cloudTable(e.key) == table.actualTableName,
      )) {
        if (reset.contains(entry.key)) {
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
        if (!reset.contains(entry.key) &&
            cloudEqual(current[entry.key], entry.value)) {
          continue;
        }
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
  }

  // Only files being replaced are journaled. The SQLite commit marker lets a
  // restarted process distinguish a completed apply from a rolled-back one.
  Directory get _staging =>
      Directory(p.join(recoveryRoot.path, 'sync-staging'));

  Future<void> _recoverFiles() async {
    final journal = File(p.join(_staging.path, 'journal.json'));
    if (!await journal.exists()) {
      if (await _staging.exists()) await _staging.delete(recursive: true);
      return;
    }
    final data =
        jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    if ((await _local.state())['applied_operation'] != data['operation']) {
      for (final item in (data['files'] as List).reversed) {
        final target = await _safeFile(item['path'] as String);
        final previous = File(
          p.join(_staging.path, 'previous', item['slot'] as String),
        );
        final incoming = File(
          p.join(_staging.path, 'downloads', item['slot'] as String),
        );
        if (await previous.exists()) {
          if (await target.exists()) await target.delete();
          await target.parent.create(recursive: true);
          await previous.rename(target.path);
        } else if (item['existed'] == false &&
            item['incoming'] == true &&
            !await incoming.exists() &&
            await target.exists()) {
          await target.delete();
        }
      }
    }
    await _staging.delete(recursive: true);
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

    try {
      var state = await info(includeBaseline: false);
      await _recoverFiles();
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
        final pending =
            jsonDecode(state['pending'] as String) as Map<String, dynamic>;
        // Accept pending requests written by the earlier full-snapshot client.
        final request = (pending['request'] ?? pending) as Map<String, dynamic>;
        try {
          final receipt = await _remote(
            () => remote.commit(token, request),
            progress,
          );
          _checkReceipt(receipt, request);
          // Accepted local edits become the common ancestor even if the response
          // was lost. Newer edits made during/after that request remain dirty.
          if (pending['localChanges'] is Map) {
            final baseline = cloudRowsFromJson(
              jsonDecode((await info())['baseline'] as String),
            );
            for (final entry in (pending['localChanges'] as Map).entries) {
              if (entry.value == null) {
                baseline.remove(entry.key);
              } else {
                baseline[entry.key as String] = Map<String, dynamic>.from(
                  entry.value as Map,
                );
              }
            }
            await db.customStatement(
              'UPDATE local_cloud_sync SET baseline=? WHERE id=1',
              [cloudCanonical(baseline)],
            );
          }
        } on CloudApiException catch (error) {
          if (error.code != 'head_changed') rethrow;
        }
        await db.customStatement(
          'UPDATE local_cloud_sync SET pending=NULL WHERE id=1',
        );
      }
      state = await info(includeBaseline: false);
      final cursor = await _local.state();
      final savedHead = cursor['head'] as int?;
      progress('Checking sync revisions…');
      final serverHead = await _remote(() => remote.status(token), progress);
      final files = await _fileRows();
      if (savedHead != null &&
          savedHead == serverHead &&
          cursor['synced_version'] == await _local.version() &&
          cloudEqual(files, jsonDecode(cursor['file_manifest'] as String))) {
        final syncedAt = DateTime.now().toUtc();
        await db.transaction(() async {
          if (cursor['synced_version'] != await _local.version()) {
            throw const CloudSyncFailure(
              'Local edits arrived during sync. Please retry.',
            );
          }
          await db.customStatement(
            'UPDATE local_cloud_sync SET last_sync=? WHERE id=1',
            [syncedAt.toIso8601String()],
          );
        });
        return CloudSyncOutcome(
          lastSync: syncedAt,
          backupPath: state['backup_path'] as String?,
          message: 'Everything is already synchronized.',
        );
      }
      final base = cloudRowsFromJson(
        jsonDecode((await info())['baseline'] as String),
      );
      final cachedRevisions =
          (jsonDecode(cursor['revisions'] as String) as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, value as int));
      CloudSnapshot cloud;
      if (savedHead == null || serverHead < savedHead) {
        progress('Reading the cloud library for this device…');
        cloud = await _remote(() => remote.snapshot(token), progress);
      } else if (savedHead == serverHead) {
        cloud = CloudSnapshot(
          head: savedHead,
          rows: Map.of(base),
          revisions: cachedRevisions,
        );
      } else {
        progress('Receiving changed records…');
        final delta = await _remote(
          () => remote.changes(token, savedHead),
          progress,
        );
        if (delta.head < savedHead ||
            delta.revisions.values.any((r) => r <= savedHead)) {
          throw const CloudSyncFailure(
            'Invalid server change cursor. Please retry.',
          );
        }
        final rows = Map.of(base);
        for (final key in delta.revisions.keys) {
          final row = delta.rows[key];
          if (row == null) {
            rows.remove(key);
          } else {
            rows[key] = row;
          }
        }
        cloud = CloudSnapshot(
          head: delta.head,
          rows: rows,
          revisions: {...cachedRevisions, ...delta.revisions},
        );
      }
      progress('Checking local changes…');
      late int localVersion;
      final databaseRows = await db.transaction(() async {
        localVersion = await _local.version();
        return _local.rows(base, full: savedHead == null);
      });
      final local = _withMissingDownloads(databaseRows, files, {
        ...cloud.rows,
        ...base,
      });
      if (savedHead != null &&
          cloud.head == savedHead &&
          cloudEqual(local, base) &&
          cloudEqual(
            files,
            Map.of(base)
              ..removeWhere((key, _) => cloudTable(key) != 'material_files'),
          )) {
        final syncedAt = DateTime.now().toUtc();
        await db.transaction(() async {
          if (await _local.version() != localVersion) {
            throw const CloudSyncFailure(
              'Local edits arrived during sync. Please retry.',
            );
          }
          await db.customStatement(
            'UPDATE local_cloud_sync SET last_sync=? WHERE id=1',
            [syncedAt.toIso8601String()],
          );
          await db.customStatement('DELETE FROM local_cloud_sync_dirty');
          await db.customStatement(
            'UPDATE local_cloud_sync_cursor SET synced_version=change_version WHERE id=1',
          );
        });
        return CloudSyncOutcome(
          lastSync: syncedAt,
          backupPath: state['backup_path'] as String?,
          message: 'Everything is already synchronized.',
        );
      }
      final schema = await _schema;
      for (final entry in cloud.rows.entries) {
        schema.validateRow(entry.key, entry.value);
      }
      schema.validate(cloud.rows);
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
      final backupPath = state['backup_path'] as String?;
      final downloads = <String, File>{};
      if (changed) {
        work = _staging;
        await work.create(recursive: true);
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
            if (!await source.exists() || await hashFile(source) != digest) {
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
                await hashFile(target) != digest) {
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
          [
            jsonEncode({
              'request': request,
              'localChanges': {
                for (final m in mutations)
                  if (cloudEqual(
                    local[cloudKey(m['table'] as String, m['id'] as String)],
                    m['data'],
                  ))
                    cloudKey(m['table'] as String, m['id'] as String):
                        m['data'],
              },
            }),
          ],
        );
      }
      final syncedAt = DateTime.now().toUtc();
      var remoteAttempted = false;
      try {
        // Check before publishing, and again in the short local transaction.
        if (await _local.version() != localVersion) {
          throw const CloudSyncFailure(
            'Local records changed during sync. Please retry; new edits were preserved.',
          );
        }
        var committedHead = cloud.head;
        final revisions = Map.of(cloud.revisions);
        if (mutations.isNotEmpty) {
          progress('Sending changed records…');
          remoteAttempted = true;
          final receipt = await _remote(
            () => remote.commit(token, request),
            progress,
          );
          if (receipt.accepted.length != mutations.length ||
              receipt.head < cloud.head) {
            throw const CloudSyncFailure(
              'Invalid server commit receipt. Retry to check the accepted operation.',
            );
          }
          for (final mutation in mutations) {
            final revision = receipt.accepted[mutation['mutationId']];
            if (revision == null ||
                revision <= cloud.head ||
                revision > receipt.head) {
              throw const CloudSyncFailure(
                'Invalid server record revision. Retry to check the accepted operation.',
              );
            }
            revisions[cloudKey(
                  mutation['table'] as String,
                  mutation['id'] as String,
                )] =
                revision;
          }
          committedHead = receipt.head;
        }
        if (!cloudEqual(await _fileRows(), files)) {
          throw const CloudSyncFailure(
            'A file changed while syncing. Its local copy was preserved; sync again.',
          );
        }
        final fileChanges = <Map<String, dynamic>>[];
        for (final key in {...files.keys, ...desiredFiles.keys}) {
          if (cloudEqual(files[key], desiredFiles[key])) continue;
          final target = await _safeFile(cloudId(key));
          final incoming = downloads[key];
          fileChanges.add({
            'path': cloudId(key),
            'slot': incoming == null ? _uuid.v4() : p.basename(incoming.path),
            'existed': await target.exists(),
            'incoming': incoming != null,
          });
        }
        if (fileChanges.isNotEmpty) {
          final journal = File(p.join(work!.path, 'journal.tmp'));
          await journal.writeAsString(
            jsonEncode({
              'operation': request['operationId'],
              'files': fileChanges,
            }),
            flush: true,
          );
          await journal.rename(p.join(work.path, 'journal.json'));
        }
        await db.transaction(() async {
          if (await _local.version() != localVersion) {
            throw const CloudSyncFailure(
              'Local records changed during sync. Please retry; new edits were preserved.',
            );
          }
          progress('Saving changed records…');
          for (final item in fileChanges) {
            final target = await _safeFile(item['path'] as String);
            final slot = item['slot'] as String;
            if (item['existed'] == true) {
              final previous = File(p.join(work!.path, 'previous', slot));
              await previous.parent.create(recursive: true);
              await target.rename(previous.path);
            }
            if (item['incoming'] == true) {
              await target.parent.create(recursive: true);
              await File(
                p.join(work!.path, 'downloads', slot),
              ).rename(target.path);
            }
          }
          if (!cloudEqual(local, desired)) {
            await _replaceRows(db, desired, databaseRows, schema);
          }
          await db.customStatement(
            'UPDATE local_cloud_sync SET baseline=?,pending=NULL,last_sync=? WHERE id=1',
            [cloudCanonical(desired), syncedAt.toIso8601String()],
          );
          await _local.saved(
            committedHead,
            revisions,
            request['operationId'] as String,
            desiredFiles,
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
        await _recoverFiles();
        rethrow;
      }
      await _recoverFiles();
      db.notifyUpdates({
        for (final table in db.allTables) TableUpdate.onTable(table),
      });
      return CloudSyncOutcome(
        lastSync: syncedAt,
        backupPath: backupPath,
        message: changed
            ? 'Library synchronized.'
            : 'Everything is already synchronized.',
      );
    } finally {
      try {
        if (work != null &&
            await work.exists() &&
            !await File(p.join(work.path, 'journal.json')).exists()) {
          await work.delete(recursive: true);
        }
      } finally {
        _running = false;
      }
    }
  }
}
