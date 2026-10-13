import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/app/routes.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/flashcards/presentation/flashcard_study_screen.dart';
import 'package:study_vault/features/flashcards/presentation/flashcards_list_screen.dart';
import 'package:study_vault/features/favorites/data/favorites_providers.dart';
import 'package:study_vault/features/flashcards/data/flashcards_providers.dart';
import 'package:study_vault/features/study_review/domain/review_models.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_day.dart';
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

  test('flashcard reviews persist due dates and restart after Again', () async {
    await seed();
    final now = DateTime(2026, 10, 13, 14);
    await db.insertFlashcard(
      FlashcardsCompanion.insert(
        id: 'card',
        front: 'Question',
        back: 'Answer',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final repository = FlashcardReviewRepository(db);
    await repository.rate('card', ReviewRating.good, now: now);
    var events = await db.select(db.flashcardReviewEvents).get();
    expect(events.single.dueOn, ScheduleDay.format(ScheduleDay.add(now, 3)));
    expect(events.single.intervalDays, 3);
    await repository.rate(
      'card',
      ReviewRating.again,
      now: DateTime(2026, 10, 16, 16),
    );
    events = await db.select(db.flashcardReviewEvents).get();
    expect(events, hasLength(2));
    final latest = latestFlashcardReviews(events)['card']!;
    expect(latest.rating, 'again');
    expect(latest.dueOn, '2026-10-17');
    expect(latest.sequenceNumber, 2);
    await expectLater(
      repository.rate('missing', ReviewRating.good),
      throwsStateError,
    );
  });

  testWidgets('subject-only card opens study without a lesson', (tester) async {
    await tester.runAsync(() async {
      await seed();
      final now = DateTime.now();
      await db.insertFlashcard(
        FlashcardsCompanion.insert(
          id: 'subject-card',
          subjectId: const Value('s'),
          front: 'Subject-only question',
          back: 'Answer',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    final cards = await tester.runAsync(() => db.watchAllFlashcards().first);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allFlashcardsProvider.overrideWith((ref) => Stream.value(cards!)),
          flashcardsForSubjectProvider(
            's',
          ).overrideWith((ref) => Stream.value(cards!)),
          flashcardReviewEventsProvider.overrideWith((ref) => Stream.value([])),
          isFavoriteProvider(
            favoriteKey('flashcard', 'subject-card'),
          ).overrideWith((ref) => Stream.value(false)),
        ],
        child: const MaterialApp(
          onGenerateRoute: onGenerateRoute,
          home: FlashcardsListScreen(scope: FlashcardsListScope.all()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subject-only question'));
    await tester.pumpAndSettle();
    expect(find.byType(FlashcardStudyScreen), findsOneWidget);
    expect(find.text('Reveal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('study session shows due cards and review ratings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final now = DateTime.now();
      for (final id in ['due', 'later']) {
        await db.insertFlashcard(
          FlashcardsCompanion.insert(
            id: id,
            front: '$id question',
            back: 'Answer',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await FlashcardReviewRepository(
        db,
      ).rate('later', ReviewRating.good, now: now);
    });
    final cards = (await tester.runAsync(() => db.watchAllFlashcards().first))!;
    final events = (await tester.runAsync(
      () => db.select(db.flashcardReviewEvents).get(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allFlashcardsProvider.overrideWith((ref) => Stream.value(cards)),
          flashcardReviewEventsProvider.overrideWith(
            (ref) => Stream.value(events),
          ),
        ],
        child: const MaterialApp(
          home: FlashcardStudyScreen(scope: FlashcardsListScope.all()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('due question'), findsOneWidget);
    expect(find.text('later question'), findsNothing);
    await tester.tap(find.text('Reveal'));
    await tester.pump();
    for (final label in ['Again', 'Hard', 'Good', 'Easy']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('All cards'));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

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
