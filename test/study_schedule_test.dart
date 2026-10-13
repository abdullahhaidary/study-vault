import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/study_review/domain/review_models.dart';
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
        ReviewScheduler.start(today: _today, mastered: true, examOn: _day(5))
            .intervalDays,
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
}
