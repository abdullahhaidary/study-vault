import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';

void main() {
  test('server sync schema matches every local table and constraint', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final schema = await CloudSyncSchema.load(db);
    final file = File('sync-server/src/library-schema.json');
    if (const bool.fromEnvironment('UPDATE_CLOUD_SCHEMA')) {
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(schema.toJson())}\n',
      );
    }
    expect(schema.tables, hasLength(25));
    expect(
      cloudCanonical(jsonDecode(await file.readAsString())),
      cloudCanonical(schema.toJson()),
    );
  });
}
