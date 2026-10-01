import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/built_in_data.dart';
import 'package:study_vault/features/search/data/study_search_service.dart';
import 'package:study_vault/features/search/domain/study_search_result.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';

void main() {
  late AppDatabase db;
  late StudySearchService search;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // onCreate seeds categories for forTesting via migration onCreate
    await db.seedBuiltInCategories();
    search = StudySearchService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedHierarchy() async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c1',
        name: 'Machine Learning',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's1',
        classId: 'c1',
        name: 'ML Fundamentals',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l1',
        subjectId: 's1',
        name: 'Linear Regression',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'm1',
        lessonId: 'l1',
        title: 'ML-L4-notes.pdf',
        originalFileName: 'ML-L4-notes.pdf',
        storedFileName: 'uuid.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('built-in categories exist exactly once', () async {
    await db.seedBuiltInCategories();
    await db.seedBuiltInCategories();
    final cats = await db.getAllCategories();
    expect(cats, hasLength(BuiltInPinCategories.seeds.length));
    expect(cats.map((c) => c.id).toSet(), hasLength(cats.length));
    expect(cats.any((c) => c.id == BuiltInPinCategories.formula), isTrue);
  });

  test('search finds class/subject/lesson/material titles', () async {
    await seedHierarchy();

    final classes = await search.search(query: 'machine');
    expect(classes.any((r) => r.kind == StudyEntityKind.class_), isTrue);

    final subjects = await search.search(query: 'fundamentals');
    expect(subjects.any((r) => r.kind == StudyEntityKind.subject), isTrue);

    final lessons = await search.search(query: 'regression');
    expect(lessons.any((r) => r.kind == StudyEntityKind.lesson), isTrue);

    final materials = await search.search(query: 'ML-L4');
    expect(materials.any((r) => r.kind == StudyEntityKind.material), isTrue);
  });

  test('search is case-insensitive and filters by type', () async {
    await seedHierarchy();
    final results = await search.search(
      query: 'MACHINE',
      typeFilter: SearchResultFilter.classes,
    );
    expect(results, isNotEmpty);
    expect(results.every((r) => r.kind == StudyEntityKind.class_), isTrue);
  });

  test(
    'pin short text, selected text, and plain note are searchable',
    () async {
      await seedHierarchy();
      final now = DateTime.now();
      final rich = jsonEncode([
        {'insert': 'The learning rate scales updates\n'},
      ]);
      final plain = StudyNoteCodec.plainTextPreview(rich);

      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'p1',
          resourceId: 'm1',
          pinType: const Value('point'),
          categoryId: const Value(BuiltInPinCategories.formula),
          pageNumber: const Value(18),
          xRatio: 0.2,
          yRatio: 0.3,
          shortText: 'Gradient Descent',
          fullExplanation: Value(rich),
          fullExplanationPlainText: Value(plain),
          selectedText: const Value('moves opposite the gradient'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        (await search.search(
          query: 'gradient descent',
        )).any((r) => r.id == 'p1'),
        isTrue,
      );
      expect(
        (await search.search(
          query: 'opposite the gradient',
        )).any((r) => r.id == 'p1'),
        isTrue,
      );
      expect(
        (await search.search(query: 'learning rate')).any((r) => r.id == 'p1'),
        isTrue,
      );

      final filtered = await search.search(
        query: 'gradient',
        typeFilter: SearchResultFilter.pins,
        categoryId: BuiltInPinCategories.formula,
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.categoryName, 'Formula');
    },
  );

  test('pin category can be set without changing annotation type', () async {
    await seedHierarchy();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        pinType: const Value('text'),
        categoryId: const Value(BuiltInPinCategories.definition),
        pageNumber: const Value(1),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Cost Function',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final pin = await db.getStudyPinById('p1');
    expect(pin!.pinType, 'text');
    expect(pin.categoryId, BuiltInPinCategories.definition);

    await db.updateStudyPin(
      pin.copyWith(categoryId: const Value(BuiltInPinCategories.exam)),
    );
    final updated = await db.getStudyPinById('p1');
    expect(updated!.pinType, 'text');
    expect(updated.categoryId, BuiltInPinCategories.exam);
  });

  test('favorites add/remove and uniqueness', () async {
    await seedHierarchy();
    await db.addFavorite(
      id: 'f1',
      entityType: FavoriteEntityType.subject,
      entityId: 's1',
    );
    await db.addFavorite(
      id: 'f2',
      entityType: FavoriteEntityType.subject,
      entityId: 's1',
    );
    expect(await db.isFavorite(FavoriteEntityType.subject, 's1'), isTrue);
    final favs = await db
        .watchFavoritesOfType(FavoriteEntityType.subject)
        .first;
    expect(favs, hasLength(1));

    await db.removeFavorite(FavoriteEntityType.subject, 's1');
    expect(await db.isFavorite(FavoriteEntityType.subject, 's1'), isFalse);
  });

  test('deleting material cleans pin favorites', () async {
    await seedHierarchy();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Pin',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.addFavorite(
      id: 'f1',
      entityType: FavoriteEntityType.studyPin,
      entityId: 'p1',
    );
    await db.addFavorite(
      id: 'f2',
      entityType: FavoriteEntityType.material,
      entityId: 'm1',
    );

    await db.deleteLessonMaterial('m1');
    expect(await db.isFavorite(FavoriteEntityType.studyPin, 'p1'), isFalse);
    expect(await db.isFavorite(FavoriteEntityType.material, 'm1'), isFalse);
  });

  test('pin can be category + favorite simultaneously', () async {
    await seedHierarchy();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        categoryId: const Value(BuiltInPinCategories.important),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Important idea',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.addFavorite(
      id: 'f1',
      entityType: FavoriteEntityType.studyPin,
      entityId: 'p1',
    );
    final pin = await db.getStudyPinById('p1');
    expect(pin!.categoryId, BuiltInPinCategories.important);
    expect(await db.isFavorite(FavoriteEntityType.studyPin, 'p1'), isTrue);
  });

  test('favorites-only search filter works', () async {
    await seedHierarchy();
    await db.addFavorite(
      id: 'f1',
      entityType: FavoriteEntityType.class_,
      entityId: 'c1',
    );
    final all = await search.search(query: 'machine');
    final favOnly = await search.search(query: 'machine', favoritesOnly: true);
    expect(all.length, greaterThanOrEqualTo(favOnly.length));
    expect(favOnly.every((r) => r.isFavorite), isTrue);
  });

  test('Persian and Yeh/Kaf-normalized pin search', () async {
    await seedHierarchy();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p_fa',
        resourceId: 'm1',
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'گرادیان نزولی',
        selectedText: const Value('یک الگوریتم بهینه‌سازی'),
        fullExplanationPlainText: const Value(
          'Gradient Descent یک الگوریتم بهینه‌سازی است.',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      (await search.search(query: 'گرادیان')).any((r) => r.id == 'p_fa'),
      isTrue,
    );
    // Arabic Yeh in query should still match Persian Yeh in storage.
    expect(
      (await search.search(query: 'گراد\u064Aان')).any((r) => r.id == 'p_fa'),
      isTrue,
    );
    expect(
      (await search.search(query: 'Gradient')).any((r) => r.id == 'p_fa'),
      isTrue,
    );
  });
}
