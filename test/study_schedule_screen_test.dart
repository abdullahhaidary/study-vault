import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/study_review/data/review_session_providers.dart';
import 'package:study_vault/features/study_schedule/data/study_schedule_providers.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_day.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_models.dart';
import 'package:study_vault/features/study_schedule/presentation/schedule_review_screen.dart';
import 'package:study_vault/features/study_schedule/presentation/study_schedule_screen.dart';

ScheduleEntry _entry(String id, int dueOffset) {
  final today = ScheduleDay.today();
  return ScheduleEntry(
    lessonId: id,
    lessonName: 'Lesson $id',
    subjectId: 's',
    subjectName: 'Biology',
    paused: false,
    dueOn: ScheduleDay.add(today, dueOffset),
    intervalDays: 3,
    lastOn: ScheduleDay.add(today, dueOffset - 3),
    reviewCount: 1,
  );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  List<Override> overrides(List<ScheduleEntry> entries) => [
    databaseProvider.overrideWithValue(db),
    scheduleEntriesProvider.overrideWith((ref) => Stream.value(entries)),
    scheduleDailyLimitProvider.overrideWith((ref) async => 2),
    unscheduledReviewedLessonsProvider.overrideWith((ref) async => const []),
    lessonSummariesProvider.overrideWith(
      (ref, id) async => [
        (title: 'Cells.pdf', markdown: 'Mitosis has **4** phases.'),
      ],
    ),
    reviewableCountProvider.overrideWith((ref, scope) async => 0),
  ];

  testWidgets('list splits today, over-limit and upcoming reviews', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides([
          _entry('a', -2),
          _entry('b', 0),
          _entry('c', -1),
          _entry('d', 5),
        ]),
        child: const MaterialApp(home: StudyScheduleScreen()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('2 reviews today'), findsOneWidget);
    expect(find.text('Today (2)'), findsOneWidget);
    expect(find.text('Also due (1)'), findsOneWidget);
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.textContaining('2 days overdue'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Review'), findsNWidgets(3));
  });

  testWidgets('review asks for recall before showing the summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides([_entry('a', 0)]),
        child: const MaterialApp(home: ScheduleReviewScreen(lessonId: 'a')),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.textContaining('recall from memory'), findsOneWidget);
    expect(find.textContaining('Mitosis'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Prophase, metaphase');
    await tester.tap(find.text('Check my notes'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('Prophase, metaphase'), findsOneWidget);
    expect(find.text('Cells.pdf'), findsOneWidget);
    expect(find.text('How much did you recall?'), findsOneWidget);
    for (final label in ['Again', 'Hard', 'Good', 'Easy']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
