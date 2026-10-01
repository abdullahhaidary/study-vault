import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/built_in_data.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';
import 'package:study_vault/features/study_review/data/review_session_providers.dart';
import 'package:study_vault/features/study_review/data/study_review_service.dart';
import 'package:study_vault/features/study_review/domain/review_models.dart';
import 'package:study_vault/features/study_review/presentation/review_session_screen.dart';

void main() {
  late AppDatabase db;
  late StudyReviewService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedBuiltInCategories();
    service = StudyReviewService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedTree({bool withExtraLesson = false}) async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c1',
        name: 'ML',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's1',
        classId: 'c1',
        name: 'Fundamentals',
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
    if (withExtraLesson) {
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l2',
          subjectId: 's1',
          name: 'Other',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'm2',
          lessonId: 'l2',
          title: 'other.pdf',
          originalFileName: 'other.pdf',
          storedFileName: 'other.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'p_out',
          resourceId: 'm2',
          xRatio: 0.1,
          yRatio: 0.1,
          shortText: 'Outside scope',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'm1',
        lessonId: 'l1',
        title: 'notes.pdf',
        originalFileName: 'notes.pdf',
        storedFileName: 'notes.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test(
    'load review items for lesson and material; exclude outside scope',
    () async {
      await seedTree(withExtraLesson: true);
      final now = DateTime.now();
      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'p1',
          resourceId: 'm1',
          pinType: const Value('point'),
          categoryId: const Value(BuiltInPinCategories.formula),
          pageNumber: const Value(2),
          xRatio: 0.2,
          yRatio: 0.3,
          shortText: 'Gradient Descent',
          fullExplanation: const Value('moves opposite gradient'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'p2',
          resourceId: 'm1',
          pinType: const Value('text'),
          selectedText: const Value('learning rate'),
          xRatio: 0.2,
          yRatio: 0.4,
          shortText: 'LR',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final lessonItems = await service.loadItems(
        scope: const ReviewScope(
          type: ReviewScopeType.lesson,
          id: 'l1',
          title: 'Linear Regression',
        ),
        filters: const ReviewSessionFilters(shuffle: false),
      );
      expect(lessonItems.map((i) => i.studyPinId).toSet(), {'p1', 'p2'});
      expect(lessonItems.any((i) => i.studyPinId == 'p_out'), isFalse);

      final materialItems = await service.loadItems(
        scope: const ReviewScope(
          type: ReviewScopeType.material,
          id: 'm1',
          title: 'notes.pdf',
        ),
        filters: const ReviewSessionFilters(shuffle: false),
      );
      expect(materialItems.map((i) => i.studyPinId).toSet(), {'p1', 'p2'});

      final subjectItems = await service.loadItems(
        scope: const ReviewScope(
          type: ReviewScopeType.subject,
          id: 's1',
          title: 'Fundamentals',
        ),
        filters: const ReviewSessionFilters(shuffle: false),
      );
      expect(subjectItems.map((i) => i.studyPinId).toSet(), {
        'p1',
        'p2',
        'p_out',
      });
    },
  );

  test('filter by category and favorites', () async {
    await seedTree();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        categoryId: const Value(BuiltInPinCategories.formula),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Formula pin',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p2',
        resourceId: 'm1',
        categoryId: const Value(BuiltInPinCategories.definition),
        xRatio: 0.2,
        yRatio: 0.2,
        shortText: 'Definition pin',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.addFavorite(
      id: 'f1',
      entityType: FavoriteEntityType.studyPin,
      entityId: 'p1',
    );

    final filtered = await service.loadItems(
      scope: const ReviewScope(
        type: ReviewScopeType.lesson,
        id: 'l1',
        title: 'L',
      ),
      filters: ReviewSessionFilters(
        shuffle: false,
        categoryIds: {BuiltInPinCategories.formula},
      ),
    );
    expect(filtered, hasLength(1));
    expect(filtered.first.studyPinId, 'p1');

    final favs = await service.loadItems(
      scope: const ReviewScope(
        type: ReviewScopeType.lesson,
        id: 'l1',
        title: 'L',
      ),
      filters: const ReviewSessionFilters(shuffle: false, favoritesOnly: true),
    );
    expect(favs, hasLength(1));
    expect(favs.first.isFavorite, isTrue);
  });

  test('point/text and rich note content returned', () async {
    await seedTree();
    final now = DateTime.now();
    final rich = StudyNoteCodec.encode(
      Document.fromJson([
        {'insert': 'Rich answer body\n'},
      ]),
    );
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        pinType: const Value('text'),
        selectedText: const Value('selected'),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Q',
        fullExplanation: Value(rich),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final items = await service.loadItems(
      scope: const ReviewScope(
        type: ReviewScopeType.material,
        id: 'm1',
        title: 'notes',
      ),
      filters: const ReviewSessionFilters(shuffle: false),
    );
    expect(items.single.fullNote, rich);
    expect(items.single.hasSelectedText, isTrue);
  });

  test('session start, reveal, rate, again once, complete counts', () async {
    await seedTree();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'p$i',
          resourceId: 'm1',
          xRatio: 0.1,
          yRatio: 0.1 + i * 0.1,
          shortText: 'Pin $i',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(activeReviewSessionProvider.notifier);
    await notifier.start(
      scope: const ReviewScope(
        type: ReviewScopeType.material,
        id: 'm1',
        title: 'notes',
      ),
      filters: const ReviewSessionFilters(shuffle: false),
    );

    var state = container.read(activeReviewSessionProvider)!;
    expect(state.items, hasLength(3));
    expect(state.revealed, isFalse);
    expect(state.currentItem!.studyPinId, 'p0');

    notifier.reveal();
    state = container.read(activeReviewSessionProvider)!;
    expect(state.revealed, isTrue);

    await notifier.rate(ReviewRating.again); // p0 → requeue
    state = container.read(activeReviewSessionProvider)!;
    expect(state.items, hasLength(4));
    expect(state.currentItem!.studyPinId, 'p1');

    notifier.reveal();
    await notifier.rate(ReviewRating.good);
    notifier.reveal();
    await notifier.rate(ReviewRating.easy);

    state = container.read(activeReviewSessionProvider)!;
    expect(state.currentItem!.studyPinId, 'p0'); // again repeat
    expect(state.againRequeued.contains('p0'), isTrue);

    notifier.reveal();
    await notifier.rate(ReviewRating.again); // second again — no infinite
    state = container.read(activeReviewSessionProvider)!;
    expect(state.completed, isTrue);
    expect(state.items, hasLength(4));
    expect(state.ratingCounts[ReviewRating.again], 1);
    expect(state.ratingCounts[ReviewRating.good], 1);
    expect(state.ratingCounts[ReviewRating.easy], 1);

    final session = await db.getReviewSessionById(state.sessionId);
    expect(session!.completedAt, isNotNull);
    final events = await db.getReviewEventsForSession(state.sessionId);
    expect(events.length, greaterThanOrEqualTo(4));
  });

  testWidgets('full note hidden until reveal; ratings after', (tester) async {
    await seedTree();
    final now = DateTime.now();
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'p1',
        resourceId: 'm1',
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Cost Function',
        fullExplanation: const Value('J(θ) measures prediction error'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container
        .read(activeReviewSessionProvider.notifier)
        .start(
          scope: const ReviewScope(
            type: ReviewScopeType.material,
            id: 'm1',
            title: 'notes',
          ),
          filters: const ReviewSessionFilters(shuffle: false),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          home: ReviewSessionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Reveal Answer'), findsOneWidget);
    expect(find.text('J(θ) measures prediction error'), findsNothing);
    expect(find.text('Again'), findsNothing);

    await tester.tap(find.text('Reveal Answer'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('prediction error', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
  });

  test('empty review state when no pins', () async {
    await seedTree();
    final session = await service.startSession(
      scope: const ReviewScope(
        type: ReviewScopeType.lesson,
        id: 'l1',
        title: 'Empty',
      ),
    );
    expect(session.items, isEmpty);
    expect(session.completed, isTrue);
  });
}
