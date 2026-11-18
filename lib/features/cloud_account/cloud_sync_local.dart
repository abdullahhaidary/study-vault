import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/backup/backup_providers.dart'
    show kStudyVaultSchemaVersion;
import 'cloud_sync_models.dart';

/// Device-local change tracking. SQL triggers also catch cascades and external
/// SQLite writers; these tables are deliberately outside Drift and cloud sync.
class CloudSyncLocal {
  CloudSyncLocal(this.db);
  final AppDatabase db;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await db.transaction(() async {
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS local_cloud_sync_cursor ('
        'id INTEGER PRIMARY KEY CHECK(id=1), head INTEGER, schema_version INTEGER, '
        'revisions TEXT NOT NULL DEFAULT \'{}\', change_version INTEGER NOT NULL DEFAULT 0, '
        'applied_operation TEXT, synced_version INTEGER NOT NULL DEFAULT -1, '
        'file_manifest TEXT NOT NULL DEFAULT \'{}\')',
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO local_cloud_sync_cursor(id) VALUES(1)',
      );
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS local_cloud_sync_dirty ('
        'table_name TEXT NOT NULL, record_id TEXT NOT NULL, PRIMARY KEY(table_name,record_id))',
      );
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS local_cloud_sync_files ('
        'path TEXT PRIMARY KEY, signature TEXT NOT NULL, digest TEXT NOT NULL)',
      );
      for (final table in db.allTables) {
        final name = table.actualTableName;
        for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
          final ref = event == 'DELETE' ? 'OLD' : 'NEW';
          await db.customStatement(
            'CREATE TRIGGER IF NOT EXISTS "local_cloud_${name}_$event" '
            'AFTER $event ON "$name" BEGIN '
            'UPDATE local_cloud_sync_cursor SET change_version=change_version+1 WHERE id=1; '
            'INSERT INTO local_cloud_sync_dirty SELECT \'$name\',$ref.id WHERE NOT EXISTS (SELECT 1 FROM local_cloud_sync_dirty WHERE table_name=\'$name\' AND record_id=$ref.id); '
            '${event == 'UPDATE' ? "INSERT INTO local_cloud_sync_dirty SELECT '$name',OLD.id WHERE NOT EXISTS (SELECT 1 FROM local_cloud_sync_dirty WHERE table_name='$name' AND record_id=OLD.id); " : ''}'
            'END',
          );
        }
      }
      await db.customStatement(
        'UPDATE local_cloud_sync_cursor SET head=NULL, revisions=\'{}\', '
        'schema_version=? WHERE schema_version IS NULL OR schema_version<>?',
        [kStudyVaultSchemaVersion, kStudyVaultSchemaVersion],
      );
    });
    _initialized = true;
  }

  Future<Map<String, dynamic>> state() async =>
      (await db
              .customSelect('SELECT * FROM local_cloud_sync_cursor WHERE id=1')
              .getSingle())
          .data;

  Future<int> version() async => (await state())['change_version'] as int;

  Future<CloudRows> rows(CloudRows baseline, {required bool full}) async {
    final result = <String, Map<String, dynamic>>{if (!full) ...baseline}
      ..removeWhere((key, _) => cloudTable(key) == 'material_files');
    if (full) {
      for (final table in db.allTables) {
        final name = table.actualTableName;
        for (final row
            in await db.customSelect('SELECT * FROM "$name"').get()) {
          result[cloudKey(name, row.data['id'] as String)] = Map.of(row.data);
        }
      }
    } else {
      final allowed = db.allTables.map((t) => t.actualTableName).toSet();
      final changedTables = <String>{};
      for (final dirty
          in await db
              .customSelect('SELECT * FROM local_cloud_sync_dirty')
              .get()) {
        final name = dirty.data['table_name'] as String;
        if (!allowed.contains(name)) continue;
        result.remove(cloudKey(name, dirty.data['record_id'] as String));
        changedTables.add(name);
      }
      for (final name in changedTables) {
        final rows = await db
            .customSelect(
              'SELECT t.* FROM "$name" t '
              'JOIN local_cloud_sync_dirty d ON d.record_id=t.id WHERE d.table_name=?',
              variables: [Variable<String>(name)],
            )
            .get();
        for (final row in rows) {
          result[cloudKey(name, row.data['id'] as String)] = Map.of(row.data);
        }
      }
    }
    return result;
  }

  Future<void> saved(
    int head,
    Map<String, int> revisions,
    String operation,
    CloudRows files,
  ) async {
    await db.customStatement(
      'UPDATE local_cloud_sync_cursor SET head=?,revisions=?,applied_operation=?, '
      'synced_version=change_version,file_manifest=? WHERE id=1',
      [head, jsonEncode(revisions), operation, jsonEncode(files)],
    );
    await db.customStatement('DELETE FROM local_cloud_sync_dirty');
  }
}
