import '../../../core/backup/backup_providers.dart'
    show kStudyVaultSchemaVersion;
import '../../../core/database/app_database.dart';
import 'cloud_sync_models.dart';

export 'cloud_sync_models.dart';

class CloudSyncSchema {
  CloudSyncSchema(this.tables);
  final Map<String, Map<String, dynamic>> tables;

  static Future<CloudSyncSchema> load(AppDatabase db) async {
    final result = <String, Map<String, dynamic>>{};
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final columns = await db.customSelect('PRAGMA table_info("$name")').get();
      final foreign = await db
          .customSelect('PRAGMA foreign_key_list("$name")')
          .get();
      final indexes = await db.customSelect('PRAGMA index_list("$name")').get();
      final unique = <List<String>>[];
      for (final index in indexes.where((r) => r.data['unique'] == 1)) {
        if (index.data['partial'] == 1) {
          throw StateError('Partial unique indexes need a sync rule.');
        }
        final indexName = index.data['name'] as String;
        final info = await db
            .customSelect('PRAGMA index_info("$indexName")')
            .get();
        final names = info.map((r) => r.data['name'] as String).toList();
        if (!(names.length == 1 && names.single == 'id')) unique.add(names);
      }
      unique.sort((a, b) => a.join(',').compareTo(b.join(',')));
      result[name] = {
        'columns': {
          for (final c in columns)
            c.data['name'] as String: {
              'type': c.data['type'],
              'required': c.data['notnull'] == 1,
            },
        },
        'foreignKeys': [
          for (final f in foreign)
            {'column': f.data['from'], 'table': f.data['table']},
        ]..sort((a, b) => '${a['column']}'.compareTo('${b['column']}')),
        'unique': unique,
      };
    }
    return CloudSyncSchema(result);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': kStudyVaultSchemaVersion,
    'tables': tables,
  };

  void validateRow(String key, Map<String, dynamic> row) {
    if (row['id'] != cloudId(key)) {
      throw StateError('Record identity mismatch.');
    }
    final name = cloudTable(key);
    if (name == 'material_files') {
      final id = row['id'];
      if (id is! String ||
          id.isEmpty ||
          id.startsWith('/') ||
          id.contains('\\') ||
          id.contains(':') ||
          id.split('/').any((s) => s.isEmpty || s == '.' || s == '..') ||
          row['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['sha256'] as String) ||
          row['bytes'] is! int ||
          (row['bytes'] as int) < 0) {
        throw StateError('Invalid material file metadata.');
      }
      return;
    }
    final table = tables[name];
    if (table == null) throw StateError('Unsupported cloud table: $name.');
    final columns = table['columns'] as Map;
    if (row.length != columns.length ||
        row.keys.any((key) => !columns.containsKey(key))) {
      throw StateError('The cloud schema does not match this app.');
    }
    for (final entry in columns.entries) {
      final value = row[entry.key];
      final spec = entry.value as Map;
      if (value == null) {
        if (spec['required'] == true) {
          throw StateError('A required cloud value is missing.');
        }
      } else if (switch (spec['type']) {
        'TEXT' => value is! String,
        'INTEGER' => value is! int,
        'REAL' => value is! num || !value.isFinite,
        _ => true,
      }) {
        throw StateError('A cloud value has an incompatible type.');
      }
    }
  }

  List<({String child, String parent})> missingParents(CloudRows rows) {
    final result = <({String child, String parent})>[];
    for (final entry in rows.entries) {
      final table = tables[cloudTable(entry.key)];
      if (table == null) continue;
      for (final foreign in table['foreignKeys'] as List) {
        final id = entry.value[foreign['column']];
        if (id != null) {
          final parent = cloudKey(foreign['table'] as String, id as String);
          if (!rows.containsKey(parent)) {
            result.add((child: entry.key, parent: parent));
          }
        }
      }
    }
    for (final material in rows.entries.where(
      (e) => cloudTable(e.key) == 'lesson_materials',
    )) {
      final data = material.value;
      final parent = cloudKey(
        'material_files',
        'lessons/${data['lesson_id']}/${data['stored_file_name']}',
      );
      if (!rows.containsKey(parent)) {
        result.add((child: material.key, parent: parent));
      }
    }
    return result;
  }

  List<List<String>> duplicates(CloudRows rows) {
    final result = <List<String>>[];
    for (final table in tables.entries) {
      for (final raw in table.value['unique'] as List) {
        final columns = (raw as List).cast<String>();
        final seen = <String, List<String>>{};
        for (final entry in rows.entries.where(
          (e) => cloudTable(e.key) == table.key,
        )) {
          final values = columns.map((c) => entry.value[c]).toList();
          if (values.any((v) => v == null)) continue;
          seen.putIfAbsent(cloudCanonical(values), () => []).add(entry.key);
        }
        result.addAll(seen.values.where((keys) => keys.length > 1));
      }
    }
    return result;
  }

  void validate(CloudRows rows) {
    for (final entry in rows.entries) {
      validateRow(entry.key, entry.value);
    }
    if (missingParents(rows).isNotEmpty) {
      throw StateError('Related cloud records are missing.');
    }
    if (duplicates(rows).isNotEmpty) {
      throw StateError('Cloud records violate a uniqueness constraint.');
    }
    for (final entry in rows.entries) {
      final path = cloudFilePath(cloudTable(entry.key), entry.value);
      if (path != null && !rows.containsKey(cloudKey('material_files', path))) {
        throw StateError(
          'A PDF or image is missing. Restore its file before synchronizing.',
        );
      }
    }
  }
}
