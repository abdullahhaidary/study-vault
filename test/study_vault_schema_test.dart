import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/flashcards/data/flashcards_providers.dart';
import 'package:study_vault/features/study_pins/domain/pin_type.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    final now = DateTime(2026);
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
        id: 'm',
        lessonId: 'l',
        title: 'Material',
        originalFileName: 'a.pdf',
        storedFileName: 'a.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('progress defaults and studying activity is queryable', () async {
    await seed();
    expect((await db.getLessonById('l'))!.progressStatus, 'notStarted');
    await db.recordLessonStudyActivity('l');
    final lesson = (await db.getLessonById('l'))!;
    expect(lesson.progressStatus, 'studying');
    expect(lesson.lastStudiedAt, isNotNull);
    expect(await db.watchStudyingLessons().first, hasLength(1));
    await db.updateLessonProgress(lessonId: 'l', progressStatus: 'mastered');
    expect((await db.getLessonById('l'))!.progressStatus, 'mastered');
  });

  test('bookmark uniqueness permits one bookmark per material page', () async {
    await seed();
    final now = DateTime.now();
    final entry = MaterialBookmarksCompanion.insert(
      id: 'b',
      materialId: 'm',
      pageNumber: 2,
      createdAt: now,
      updatedAt: now,
    );
    await db.insertMaterialBookmark(entry);
    expect(await db.getBookmarkForPage('m', 2), isNotNull);
    expect(
      db.insertMaterialBookmark(entry.copyWith(id: const Value('b2'))),
      throwsA(isA<Exception>()),
    );
  });

  test('pin defaults map text, point, and question flashcards', () {
    final now = DateTime.now();
    final text = StudyPin(
      id: 'p',
      resourceId: 'm',
      pinType: 'text',
      categoryId: null,
      pageNumber: 1,
      xRatio: 0,
      yRatio: 0,
      shortText: 'Short',
      fullExplanation: null,
      fullExplanationPlainText: null,
      selectedText: 'Selected',
      sortOrder: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    expect(defaultsFromStudyPin(text).front, 'Selected');
    final point = text.copyWith(
      pinType: 'point',
      selectedText: const Value(null),
    );
    expect(defaultsFromStudyPin(point).front, 'Short');
    final question = point.copyWith(categoryId: const Value('cat_question'));
    expect(defaultsFromStudyPin(question).front, 'Short');
    expect(StudyPinType.fromDb(text.pinType), StudyPinType.text);
  });

  test('flashcard source pin becomes null when its pin is deleted', () async {
    await seed();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p',
        resourceId: 'm',
        pinType: const Value('point'),
        pageNumber: const Value(1),
        xRatio: 0,
        yRatio: 0,
        shortText: 'Pin',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertFlashcard(
      FlashcardsCompanion.insert(
        id: 'f',
        subjectId: const Value('s'),
        lessonId: const Value('l'),
        sourceStudyPinId: const Value('p'),
        front: 'Front',
        back: 'Back',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.deleteStudyPin('p');
    expect((await db.getFlashcardById('f'))!.sourceStudyPinId, isNull);
  });
}
