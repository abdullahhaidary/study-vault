import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';

void main() {
  final created = DateTime(2026, 10, 14);

  Future<AppDatabase> openFile(File file) async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<void> seedLibrary(AppDatabase db) async {
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c',
        name: 'C',
        createdAt: created,
        updatedAt: created,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's',
        classId: 'c',
        name: 'Subject',
        createdAt: created,
        updatedAt: created,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l',
        subjectId: 's',
        name: 'Lesson',
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  Future<void> insertMaterial(
    AppDatabase db, {
    required String id,
    String? variantOfId,
    String? language,
    int pageOffset = 0,
  }) {
    return db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: id,
        lessonId: 'l',
        title: id,
        originalFileName: '$id.pdf',
        storedFileName: '$id.pdf',
        language: Value(language),
        variantOfId: Value(variantOfId),
        pageOffset: Value(pageOffset),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  /// Rebuilds `lesson_materials` at schema 23 without the UNIQUE rule,
  /// which is how a database looked after the original version-22 upgrade.
  Future<void> stripVariantUniqueness(AppDatabase db) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'CREATE TABLE lesson_materials_nounique ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'lesson_id TEXT NOT NULL, '
      'title TEXT NOT NULL, '
      'original_file_name TEXT NOT NULL, '
      'stored_file_name TEXT NOT NULL, '
      'mime_type TEXT NOT NULL DEFAULT \'application/pdf\', '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'language TEXT, '
      'variant_of_id TEXT, '
      'page_offset INTEGER NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)',
    );
    await db.customStatement(
      'INSERT INTO lesson_materials_nounique ('
      'id, lesson_id, title, original_file_name, stored_file_name, '
      'mime_type, sort_order, language, variant_of_id, page_offset, '
      'created_at, updated_at) '
      'SELECT id, lesson_id, title, original_file_name, stored_file_name, '
      'mime_type, sort_order, language, variant_of_id, page_offset, '
      'created_at, updated_at FROM lesson_materials',
    );
    await db.customStatement('DROP TABLE lesson_materials');
    await db.customStatement(
      'ALTER TABLE lesson_materials_nounique RENAME TO lesson_materials',
    );
  }

  Future<List<String>> uniqueIndexNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM pragma_index_list(\'lesson_materials\') '
          'WHERE "unique" != 0',
        )
        .get();
    return [for (final row in rows) row.data['name'] as String];
  }

  test('fresh database uses the table constraint and no extra index', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedLibrary(db);
    await insertMaterial(db, id: 'original');

    final status = db.lessonMaterialVariantUniqueness;
    expect(status, isNotNull);
    expect(status!.enforced, isTrue);
    expect(status.duplicates, isEmpty);
    expect(db.schemaVersion, 24);
    final indexes = await uniqueIndexNames(db);
    expect(indexes, isNotEmpty);
    expect(indexes, isNot(contains(LessonMaterialVariantUniqueness.indexName)));

    await insertMaterial(db, id: 'fa', variantOfId: 'original', language: 'fa');
    expect(
      insertMaterial(db, id: 'fa-2', variantOfId: 'original', language: 'fa'),
      throwsA(isA<Exception>()),
    );
    expect(await uniqueIndexNames(db), indexes);
  });

  test(
    'current schema without the constraint gains it and keeps rows',
    () async {
      final dir = await Directory.systemTemp.createTemp('variant_repair');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/vault.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await seedLibrary(db);
      await insertMaterial(db, id: 'original');
      await insertMaterial(
        db,
        id: 'fa',
        variantOfId: 'original',
        language: 'fa',
        pageOffset: 1,
      );
      final before = (await db.getMaterialById('original'))!;
      await stripVariantUniqueness(db);
      expect(
        await uniqueIndexNames(db),
        isNot(contains(LessonMaterialVariantUniqueness.indexName)),
      );
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 24);
      await db.close();

      db = await openFile(file);
      addTearDown(db.close);
      expect(db.lessonMaterialVariantUniqueness!.enforced, isTrue);
      expect(db.lessonMaterialVariantUniqueness!.duplicates, isEmpty);
      expect(
        await uniqueIndexNames(db),
        contains(LessonMaterialVariantUniqueness.indexName),
      );
      final original = (await db.getMaterialById('original'))!;
      expect(original.title, before.title);
      expect(original.updatedAt, before.updatedAt);
      final persian = (await db.getMaterialById('fa'))!;
      expect(persian.language, 'fa');
      expect(persian.variantOfId, 'original');
      expect(persian.pageOffset, 1);
      expect(
        insertMaterial(db, id: 'fa-2', variantOfId: 'original', language: 'fa'),
        throwsA(isA<Exception>()),
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        24,
      );
    },
  );

  test('opening a protected database again does not change rows', () async {
    final dir = await Directory.systemTemp.createTemp('variant_kept');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/vault.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await seedLibrary(db);
    await insertMaterial(db, id: 'original');
    final before = (await db.getMaterialById('original'))!;
    final indexes = await uniqueIndexNames(db);
    await db.close();

    db = await openFile(file);
    addTearDown(db.close);
    expect(db.lessonMaterialVariantUniqueness!.enforced, isTrue);
    final after = (await db.getMaterialById('original'))!;
    expect(after.title, before.title);
    expect(after.updatedAt, before.updatedAt);
    expect(after.language, before.language);
    expect(await uniqueIndexNames(db), indexes);
    expect(await db.select(db.lessonMaterials).get(), hasLength(1));

    await db.close();
    db = await openFile(file);
    addTearDown(db.close);
    expect((await db.getMaterialById('original'))!.updatedAt, before.updatedAt);
    expect(await uniqueIndexNames(db), indexes);
    expect(db.lessonMaterialVariantUniqueness!.enforced, isTrue);
  });

  test(
    'duplicate companions are kept and uniqueness stays unrepaired',
    () async {
      final dir = await Directory.systemTemp.createTemp('variant_dupes');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/vault.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await seedLibrary(db);
      await insertMaterial(db, id: 'original');
      await stripVariantUniqueness(db);
      await insertMaterial(
        db,
        id: 'fa',
        variantOfId: 'original',
        language: 'fa',
      );
      await insertMaterial(
        db,
        id: 'fa-2',
        variantOfId: 'original',
        language: 'fa',
      );
      await db.close();

      db = await openFile(file);
      addTearDown(db.close);
      final status = db.lessonMaterialVariantUniqueness!;
      expect(status.enforced, isFalse);
      expect(status.blockedByDuplicates, isTrue);
      expect(status.duplicates, hasLength(1));
      expect(status.duplicates.single.variantOfId, 'original');
      expect(status.duplicates.single.language, 'fa');
      expect(status.duplicates.single.materialIds, ['fa', 'fa-2']);
      expect(await db.getMaterialById('fa'), isNotNull);
      expect(await db.getMaterialById('fa-2'), isNotNull);
      expect(await db.getMaterialById('original'), isNotNull);
      expect(
        await uniqueIndexNames(db),
        isNot(contains(LessonMaterialVariantUniqueness.indexName)),
      );

      await db.close();
      db = await openFile(file);
      addTearDown(db.close);
      expect(db.lessonMaterialVariantUniqueness!.enforced, isFalse);
      expect(await db.select(db.lessonMaterials).get(), hasLength(3));

      // Recovery is explicit: remove one companion, then open again.
      await db.deleteLessonMaterial('fa-2');
      await db.close();
      db = await openFile(file);
      addTearDown(db.close);
      expect(db.lessonMaterialVariantUniqueness!.enforced, isTrue);
      expect(db.lessonMaterialVariantUniqueness!.duplicates, isEmpty);
      expect(await db.getMaterialById('fa'), isNotNull);
      expect(await db.getMaterialById('fa-2'), isNull);
      expect(await db.getMaterialById('original'), isNotNull);
      expect(
        await uniqueIndexNames(db),
        contains(LessonMaterialVariantUniqueness.indexName),
      );
    },
  );

  test('several original PDFs with null variants stay valid', () async {
    final dir = await Directory.systemTemp.createTemp('variant_nulls');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/vault.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await seedLibrary(db);
    await insertMaterial(db, id: 'one');
    await insertMaterial(db, id: 'two');
    await stripVariantUniqueness(db);
    await db.close();

    db = await openFile(file);
    addTearDown(db.close);
    expect(db.lessonMaterialVariantUniqueness!.enforced, isTrue);
    expect(await db.getMaterialById('one'), isNotNull);
    expect(await db.getMaterialById('two'), isNotNull);
    await insertMaterial(db, id: 'three');
    expect(await db.select(db.lessonMaterials).get(), hasLength(3));
    expect(
      (await db.select(db.lessonMaterials).get()).map((row) => row.variantOfId),
      everyElement(isNull),
    );
  });
}
