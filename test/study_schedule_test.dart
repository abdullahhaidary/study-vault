import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/study_review/domain/review_models.dart';
import 'package:study_vault/features/study_schedule/data/study_schedule_repository.dart';
import 'package:study_vault/features/study_schedule/domain/review_scheduler.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_day.dart';
import 'package:study_vault/features/study_schedule/domain/schedule_models.dart';

final _today = DateTime.utc(2026, 10, 13);
DateTime _day(int offset) => ScheduleDay.add(_today, offset);

ScheduleDecision _onTime(
  int interval,
  ReviewRating rating, {
  DateTime? examOn,
  DueCount? dueCount,
  int dailyLimit = 0,
}) => ReviewScheduler.review(
  today: _today,
  lastOn: _day(-interval),
  dueOn: _today,
  intervalDays: interval,
  rating: rating,
  examOn: examOn,
  dueCount: dueCount,
  dailyLimit: dailyLimit,
);

ScheduleEntry _entry(
  String id, {
  required int due,
  int interval = 7,
  bool paused = false,
  DateTime? examOn,
}) => ScheduleEntry(
  lessonId: id,
  lessonName: id,
  subjectId: 's',
  subjectName: 'Subject',
  paused: paused,
  dueOn: _day(due),
  intervalDays: interval,
  lastOn: _day(due - interval),
  reviewCount: 1,
  examOn: examOn,
);

void main() {
  group('ScheduleDay', () {
    test('round-trips calendar days and counts across DST', () {
      expect(ScheduleDay.format(_today), '2026-10-13');
      expect(ScheduleDay.parse('2026-10-13'), _today);
      expect(ScheduleDay.tryParse('bad'), isNull);
      expect(
        ScheduleDay.between(DateTime(2026, 3, 1), DateTime(2026, 11, 1)),
        245,
      );
      expect(ScheduleDay.relative(_day(-2), today: _today), '2 days overdue');
      expect(ScheduleDay.relative(_day(1), today: _today), 'Tomorrow');
    });
  });

  group('ReviewScheduler', () {
    test('first review is tomorrow, or a week for mastered lessons', () {
      expect(ReviewScheduler.start(today: _today).dueOn, _day(1));
      expect(
        ReviewScheduler.start(today: _today, mastered: true).intervalDays,
        7,
      );
    });

    test('Good climbs the ladder 1 → 3 → 7 → 21 → 60 → 120', () {
      var interval = 1;
      final seen = <int>[];
      for (var i = 0; i < 5; i++) {
        interval = _onTime(interval, ReviewRating.good).intervalDays;
        seen.add(interval);
      }
      expect(seen, [3, 7, 21, 60, 120]);
      expect(_onTime(365, ReviewRating.good).intervalDays, 365);
    });

    test('Easy skips a rung, Hard grows slowly, Again restarts', () {
      expect(_onTime(3, ReviewRating.easy).intervalDays, 21);
      expect(_onTime(1, ReviewRating.hard).intervalDays, 2);
      expect(_onTime(21, ReviewRating.hard).intervalDays, 25);
      expect(_onTime(60, ReviewRating.again).intervalDays, 1);
    });

    test('late successful reviews get credit for the real gap', () {
      final late = ReviewScheduler.review(
        today: _today,
        lastOn: _day(-30),
        dueOn: _day(-23),
        intervalDays: 7,
        rating: ReviewRating.good,
      );
      expect(late.intervalDays, 60);
    });

    test('reviewing early never pulls a known lesson closer', () {
      final early = ReviewScheduler.review(
        today: _today,
        lastOn: _day(-2),
        dueOn: _day(19),
        intervalDays: 21,
        rating: ReviewRating.good,
      );
      expect(early.dueOn, _day(19));
      final forgot = ReviewScheduler.review(
        today: _today,
        lastOn: _day(-2),
        dueOn: _day(19),
        intervalDays: 21,
        rating: ReviewRating.again,
      );
      expect(forgot.dueOn, _day(1));
    });

    test('exam dates cap gaps so reviews land before the exam', () {
      final exam = _day(20);
      expect(_onTime(7, ReviewRating.good, examOn: exam).intervalDays, 8);
      expect(
        ReviewScheduler.start(
          today: _today,
          mastered: true,
          examOn: _day(5),
        ).intervalDays,
        2,
      );
      expect(_onTime(3, ReviewRating.good, examOn: _day(2)).intervalDays, 1);
      // After the exam the normal ladder resumes.
      expect(_onTime(7, ReviewRating.good, examOn: _day(-1)).intervalDays, 21);
    });

    test('long gaps move to a lighter nearby day when full', () {
      final full = {_day(21): 10, _day(20): 10};
      final moved = _onTime(
        7,
        ReviewRating.good,
        dueCount: (day) => full[day] ?? 0,
        dailyLimit: 10,
      );
      expect(moved.dueOn, _day(22));
      final short = _onTime(
        1,
        ReviewRating.good,
        dueCount: (_) => 99,
        dailyLimit: 10,
      );
      expect(short.dueOn, _day(3));
    });
  });

  group('SchedulePlan', () {
    test('splits due reviews by the daily limit, most urgent first', () {
      final plan = SchedulePlan.build(
        [
          _entry('upcoming', due: 3),
          _entry('due-today', due: 0),
          _entry('very-late', due: -10, interval: 3),
          _entry('paused', due: -1, paused: true),
          _entry('exam-soon', due: 0, examOn: _day(4)),
          _entry('slightly-late', due: -1, interval: 21),
        ],
        today: _today,
        dailyLimit: 3,
      );
      expect(plan.today.map((e) => e.lessonId), [
        'exam-soon',
        'very-late',
        'slightly-late',
      ]);
      expect(plan.overflow.map((e) => e.lessonId), ['due-today']);
      expect(plan.upcoming.map((e) => e.lessonId), ['upcoming']);
      expect(plan.paused.map((e) => e.lessonId), ['paused']);
      expect(plan.dueCount, 4);
    });
  });

  test(
    'upgrading a version 18 database keeps data and adds the schedule',
    () async {
      final dir = await Directory.systemTemp.createTemp('schedule_migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/vault.sqlite');
      final t = DateTime(2026);
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await db.insertClass(
        ClassesCompanion.insert(id: 'c', name: 'C', createdAt: t, updatedAt: t),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's',
          classId: 'c',
          name: 'Kept',
          createdAt: t,
          updatedAt: t,
        ),
      );
      await db.customStatement('DROP TABLE pdf_ai_material_translations');
      await db.customStatement('DROP TABLE flashcard_review_events');
      await db.customStatement('DROP TABLE study_schedule_events');
      await db.customStatement('DROP TABLE study_schedules');
      await db.customStatement('ALTER TABLE subjects DROP COLUMN exam_date');
      await db.customStatement('PRAGMA user_version = 18');
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect((await db.getSubjectById('s'))!.name, 'Kept');
      expect(await db.select(db.studySchedules).get(), isEmpty);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 21);
    },
  );

  group('StudyScheduleRepository', () {
    late AppDatabase db;
    late DateTime now;
    late StudyScheduleRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      now = DateTime(2026, 10, 13, 22, 30);
      repo = StudyScheduleRepository(db, clock: () => now);
      final t = DateTime(2026);
      await db.insertClass(
        ClassesCompanion.insert(id: 'c', name: 'C', createdAt: t, updatedAt: t),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's',
          classId: 'c',
          name: 'Biology',
          createdAt: t,
          updatedAt: t,
        ),
      );
      for (final id in ['l1', 'l2', 'l3']) {
        await db.insertLesson(
          LessonsCompanion.insert(
            id: id,
            subjectId: 's',
            name: 'Lesson $id',
            createdAt: t,
            updatedAt: t,
          ),
        );
      }
    });
    tearDown(() => db.close());

    test('enrolling is idempotent and schedules tomorrow', () async {
      expect(await repo.enroll('l1'), isTrue);
      expect(await repo.enroll('l1'), isFalse);
      final entry = (await repo.entryFor('l1'))!;
      expect(entry.dueOn, _day(1));
      expect(entry.subjectName, 'Biology');
      expect(entry.reviewCount, 0);
    });

    test('reviews climb the ladder and promote lesson progress', () async {
      await repo.enroll('l1');
      now = DateTime(2026, 10, 14, 9);
      final first = await repo.recordReview(
        'l1',
        rating: ReviewRating.good,
        recallText: '  mitosis phases  ',
      );
      expect(first.intervalDays, 3);
      expect((await db.getLessonById('l1'))!.progressStatus, 'reviewed');

      now = DateTime(2026, 10, 17, 9);
      expect(
        (await repo.recordReview('l1', rating: ReviewRating.easy)).intervalDays,
        21,
      );
      now = DateTime(2026, 11, 7, 9);
      expect(
        (await repo.recordReview('l1', rating: ReviewRating.good)).intervalDays,
        60,
      );
      expect((await db.getLessonById('l1'))!.progressStatus, 'mastered');

      final entry = (await repo.entryFor('l1'))!;
      expect(entry.reviewCount, 3);
      final events = await db.select(db.studyScheduleEvents).get();
      expect(events.map((e) => e.recallText), contains('mitosis phases'));

      await repo.recordReview('l1', rating: ReviewRating.again);
      expect((await db.getLessonById('l1'))!.progressStatus, 'reviewed');
    });

    test('a manual date change does not reset the credited gap', () async {
      await repo.enroll('l1');
      await repo.reschedule('l1', _day(5));
      final entry = (await repo.entryFor('l1'))!;
      expect(entry.dueOn, _day(5));
      expect(entry.lastOn, _today);
      expect(entry.intervalDays, 5);
    });

    test('exam dates cap new gaps and pull later reviews forward', () async {
      await repo.enroll('l2');
      await repo.reschedule('l2', _day(40));
      await repo.enroll('l3');
      expect(await repo.setExamDate('s', _day(10)), 1);
      expect((await repo.entryFor('l2'))!.dueOn, _day(4));
      expect((await repo.entryFor('l3'))!.dueOn, _day(1));
      await repo.enroll('l1', mastered: true);
      expect((await repo.entryFor('l1'))!.dueOn, _day(4));
      expect(await repo.setExamDate('s', null), 0);
      expect((await db.getSubjectById('s'))!.examDate, isNull);
    });

    test('pause, remove and lesson deletion', () async {
      await repo.enroll('l1');
      await repo.enroll('l2');
      await repo.setPaused('l1', true);
      expect((await repo.entryFor('l1'))!.paused, isTrue);
      await repo.remove('l1');
      expect(await repo.entryFor('l1'), isNull);
      await db.deleteLesson('l2');
      expect(await repo.entries(), isEmpty);
      expect(await db.select(db.studyScheduleEvents).get(), hasLength(1));
    });

    test('existing reviewed lessons are added in daily batches', () async {
      await db.updateLessonProgress(lessonId: 'l1', progressStatus: 'reviewed');
      await db.updateLessonProgress(lessonId: 'l2', progressStatus: 'mastered');
      await db.updateLessonProgress(lessonId: 'l3', progressStatus: 'reviewed');
      await repo.enroll('l3');
      final pending = await repo.unscheduledReviewedLessons();
      expect(pending.map((l) => l.id), ['l1', 'l2']);
      expect(await repo.enrollMany(pending, dailyLimit: 1), 2);
      expect((await repo.entryFor('l1'))!.dueOn, _day(1));
      expect((await repo.entryFor('l2'))!.dueOn, _day(8));
      expect(await repo.unscheduledReviewedLessons(), isEmpty);
    });
  });
}
