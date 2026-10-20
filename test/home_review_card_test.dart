import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/app/routes.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/classes/data/classes_providers.dart';
import 'package:study_vault/features/classes/presentation/home_screen.dart';
import 'package:study_vault/features/lessons/data/lesson_progress_providers.dart';
import 'package:study_vault/features/study_schedule/data/study_schedule_providers.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_day.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_models.dart';
import 'package:study_vault/features/study_schedule/presentation/study_schedule_screen.dart';

ScheduleEntry _due(String id) {
  final today = ScheduleDay.today();
  return ScheduleEntry(
    lessonId: id,
    lessonName: 'Lesson $id',
    subjectId: 's',
    subjectName: 'Biology',
    paused: false,
    dueOn: today,
    intervalDays: 1,
    lastOn: ScheduleDay.add(today, -1),
    reviewCount: 0,
  );
}

ScheduleEntry _upcoming() {
  final today = ScheduleDay.today();
  return ScheduleEntry(
    lessonId: 'later',
    lessonName: 'Later',
    subjectId: 's',
    subjectName: 'Biology',
    paused: false,
    dueOn: ScheduleDay.add(today, 4),
    intervalDays: 7,
    lastOn: today,
    reviewCount: 1,
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  List<Override> overrides(List<ScheduleEntry> entries, {required int limit}) =>
      [
        databaseProvider.overrideWithValue(db),
        classesProvider.overrideWith((ref) => Stream.value(const [])),
        subjectCountsProvider.overrideWith((ref) => Stream.value(const {})),
        continueStudyingLessonsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        scheduleEntriesProvider.overrideWith((ref) => Stream.value(entries)),
        scheduleDailyLimitProvider.overrideWith((ref) async => limit),
      ];

  Future<void> pump(WidgetTester tester, List<Override> scopeOverrides) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: scopeOverrides,
        child: MaterialApp(
          onGenerateRoute: onGenerateRoute,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('one due lesson uses the singular ready-for-review label', (
    tester,
  ) async {
    await pump(tester, overrides([_due('a')], limit: 10));

    expect(find.text('1 lesson ready for review'), findsOneWidget);
    expect(find.text('Open your Study Schedule'), findsOneWidget);
    expect(find.textContaining("today's plan"), findsNothing);
    expect(find.textContaining('flashcard'), findsNothing);
    expect(find.textContaining('pin'), findsNothing);

    await tester.tap(find.text('1 lesson ready for review'));
    await tester.pumpAndSettle();
    expect(find.byType(StudyScheduleScreen), findsOneWidget);
    expect(find.text('Study Schedule'), findsOneWidget);
  });

  testWidgets('overflow is counted apart from today\'s plan', (tester) async {
    await pump(
      tester,
      overrides([_due('a'), _due('b'), _due('c')], limit: 2),
    );

    expect(find.text("2 lesson reviews in today's plan"), findsOneWidget);
    expect(
      find.text('1 additional lesson is due beyond your daily limit.'),
      findsOneWidget,
    );
    expect(find.textContaining('ready for review'), findsNothing);
    expect(find.textContaining('tomorrow'), findsNothing);
  });

  testWidgets('several overflow lessons use the plural subtitle', (
    tester,
  ) async {
    await pump(
      tester,
      overrides([_due('a'), _due('b'), _due('c'), _due('d')], limit: 2),
    );

    expect(find.text("2 lesson reviews in today's plan"), findsOneWidget);
    expect(
      find.text('2 additional lessons are due beyond your daily limit.'),
      findsOneWidget,
    );
  });

  testWidgets('a plan with nothing due hides the review card', (tester) async {
    await pump(tester, overrides([_upcoming()], limit: 10));

    expect(find.textContaining('ready for review'), findsNothing);
    expect(find.textContaining("today's plan"), findsNothing);
    expect(find.textContaining('additional lesson'), findsNothing);
    expect(find.text('No classes yet'), findsOneWidget);
  });
}
