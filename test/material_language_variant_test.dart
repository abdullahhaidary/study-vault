import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/lessons/domain/material_language_variant.dart';

void main() {
  group('MaterialLanguageVariant.mapPage', () {
    test('keeps the same page when offset is zero', () {
      expect(
        MaterialLanguageVariant.mapPage(
          page: 7,
          fromOffset: 0,
          toOffset: 0,
          toPageCount: 20,
        ),
        7,
      );
    });

    test('applies a positive Persian cover-page offset', () {
      expect(
        MaterialLanguageVariant.mapPage(
          page: 3,
          fromOffset: 0,
          toOffset: 1,
          toPageCount: 20,
        ),
        4,
      );
      expect(
        MaterialLanguageVariant.mapPage(
          page: 4,
          fromOffset: 1,
          toOffset: 0,
          toPageCount: 20,
        ),
        3,
      );
    });

    test('clamps to the target page count', () {
      expect(
        MaterialLanguageVariant.mapPage(
          page: 20,
          fromOffset: 0,
          toOffset: 2,
          toPageCount: 20,
        ),
        20,
      );
      expect(
        MaterialLanguageVariant.mapPage(
          page: 1,
          fromOffset: 2,
          toOffset: 0,
          toPageCount: 20,
        ),
        1,
      );
    });
  });

  group('Persian companion materials', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    Future<void> seed() async {
      final now = DateTime(2026, 10, 14);
      await db.insertClass(
        ClassesCompanion.insert(
          id: 'c',
          name: 'Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's',
          classId: 'c',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l',
          subjectId: 's',
          name: 'Lesson',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'original',
          lessonId: 'l',
          title: 'Banking.pdf',
          originalFileName: 'Banking.pdf',
          storedFileName: 'original.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'persian',
          lessonId: 'l',
          title: 'فارسی · Banking.pdf',
          originalFileName: 'Banking-fa.pdf',
          storedFileName: 'persian.pdf',
          language: const Value(MaterialLanguageVariant.persian),
          variantOfId: const Value('original'),
          pageOffset: const Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    test('lesson list hides Persian companions', () async {
      await seed();
      final materials = await db.watchMaterialsForLesson('l').first;
      expect(materials.map((m) => m.id), ['original']);
    });

    test('variant lookup returns the Persian companion', () async {
      await seed();
      final persian = await db.getMaterialVariant(
        'original',
        MaterialLanguageVariant.persian,
      );
      expect(persian?.id, 'persian');
      expect(persian?.pageOffset, 1);
      expect(persian?.language, MaterialLanguageVariant.persian);
    });

    test('deleting the original removes the Persian companion row', () async {
      await seed();
      await db.deleteLessonMaterial('original');
      expect(await db.getMaterialById('original'), isNull);
      expect(await db.getMaterialById('persian'), isNull);
    });
  });
}
