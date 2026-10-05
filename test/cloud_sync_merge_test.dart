import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_merge.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';

void main() {
  late CloudSyncSchema schema;
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    schema = await CloudSyncSchema.load(db);
  });
  tearDown(() => db.close());
  Map<String, dynamic> row(
    String table,
    String id, [
    Map<String, dynamic> values = const {},
  ]) => {
    for (final entry in (schema.tables[table]!['columns'] as Map).entries)
      entry.key as String: entry.value['required'] != true
          ? null
          : switch (entry.value['type']) {
              'TEXT' => 'test',
              'INTEGER' => 1,
              _ => 0.0,
            },
    'id': id,
    ...values,
  };

  test(
    'independent edits merge and numeric encoding does not create conflicts',
    () {
      expect(cloudEqual({'x': 0.0}, {'x': 0}), isTrue);
      final a = row('classes', 'a');
      final b = row('classes', 'b');
      final plan = CloudMerge.plan(
        schema: schema,
        base: {},
        device: {'classes/a': a},
        server: {'classes/b': b},
      );
      expect(plan.conflicts, isEmpty);
      expect(plan.rows, {'classes/a': a, 'classes/b': b});
    },
  );

  test(
    'two edits to the same record require a choice and preserve independent changes',
    () {
      final original = row('classes', 'a');
      final local = {...original, 'name': 'Local'};
      final remote = {...original, 'name': 'Cloud'};
      final b = row('classes', 'b');
      final plan = CloudMerge.plan(
        schema: schema,
        base: {'classes/a': original},
        device: {'classes/a': local},
        server: {'classes/a': remote, 'classes/b': b},
      );
      expect(plan.conflicts, hasLength(1));
      final resolved = CloudMerge.plan(
        schema: schema,
        base: {'classes/a': original},
        device: {'classes/a': local},
        server: {'classes/a': remote, 'classes/b': b},
        choice: CloudConflictChoice.device,
      );
      expect(resolved.rows, {'classes/a': local, 'classes/b': b});
    },
  );

  test(
    'new child versus deleted parent is detected instead of silently discarded',
    () {
      final parent = row('classes', 'c');
      final child = row('subjects', 's', {'class_id': 'c'});
      final local = {'classes/c': parent, 'subjects/s': child};
      final plan = CloudMerge.plan(
        schema: schema,
        base: {'classes/c': parent},
        device: local,
        server: {},
      );
      expect(plan.conflicts, hasLength(1));
      final keep = CloudMerge.plan(
        schema: schema,
        base: {'classes/c': parent},
        device: local,
        server: {},
        choice: CloudConflictChoice.device,
      );
      expect(keep.rows, local);
      final remove = CloudMerge.plan(
        schema: schema,
        base: {'classes/c': parent},
        device: local,
        server: {},
        choice: CloudConflictChoice.server,
      );
      expect(remove.rows, isEmpty);
    },
  );

  test('initial system categories ignore installation timestamps only', () {
    final local = row('study_pin_categories', 'cat', {'is_system': 1});
    final remote = {...local, 'created_at': 8, 'updated_at': 9};
    final plan = CloudMerge.plan(
      schema: schema,
      base: {},
      device: {'study_pin_categories/cat': local},
      server: {'study_pin_categories/cat': remote},
    );
    expect(plan.conflicts, isEmpty);
    expect(plan.rows['study_pin_categories/cat'], remote);
  });

  test(
    'concurrent AI generations retain both outputs with distinct version numbers',
    () {
      final shared = <String, Map<String, dynamic>>{
        'classes/c': row('classes', 'c'),
        'subjects/s': row('subjects', 's', {'class_id': 'c'}),
        'lessons/l': row('lessons', 'l', {'subject_id': 's'}),
        'lesson_materials/p': row('lesson_materials', 'p', {
          'lesson_id': 'l',
          'stored_file_name': 'f.pdf',
        }),
        'material_files/lessons/l/f.pdf': {
          'id': 'lessons/l/f.pdf',
          'sha256': 'a' * 64,
          'bytes': 3,
        },
      };
      final local = row('pdf_ai_materials', 'a', {
        'material_id': 'p',
        'content': 'Local output',
        'version': 1,
      });
      final remote = row('pdf_ai_materials', 'b', {
        'material_id': 'p',
        'content': 'Cloud output',
        'version': 1,
      });
      final plan = CloudMerge.plan(
        schema: schema,
        base: shared,
        device: {...shared, 'pdf_ai_materials/a': local},
        server: {...shared, 'pdf_ai_materials/b': remote},
      );
      expect(plan.conflicts, isEmpty);
      expect(plan.rows['pdf_ai_materials/b']!['version'], 1);
      expect(plan.rows['pdf_ai_materials/a']!['version'], 2);
      expect(plan.rows['pdf_ai_materials/a']!['content'], 'Local output');
    },
  );
}
