import 'dart:math';

import '../../study_review/domain/review_models.dart' show ReviewRating;
import 'schedule_day.dart';

typedef ScheduleDecision = ({DateTime dueOn, int intervalDays});

/// Counts reviews already due on a day (for spreading the load).
typedef DueCount = int Function(DateTime day);

/// Spaced-review intervals for whole lessons.
///
/// Successful recall climbs [ladder] (Easy skips a rung), Hard grows slowly
/// and Again restarts at one day. A late but successful review is credited
/// for the full time that actually passed. With an exam date, gaps are
/// capped at [examGapFraction] of the days left so reviews land before the
/// exam — Cepeda et al. (2008) found the best gap is roughly 20–40% of a
/// short retention interval.
abstract final class ReviewScheduler {
  static const ladder = [1, 3, 7, 21, 60, 120, 240, 365];
  static const examGapFraction = 0.4;

  /// Lessons reaching this gap after a successful review count as mastered.
  static const masteredIntervalDays = 60;

  static ScheduleDecision start({
    required DateTime today,
    bool mastered = false,
    DateTime? examOn,
  }) {
    final due = _capForExam(
      ScheduleDay.add(today, mastered ? 7 : 1),
      today,
      examOn,
    );
    return (dueOn: due, intervalDays: ScheduleDay.between(today, due));
  }

  static ScheduleDecision review({
    required DateTime today,
    required DateTime lastOn,
    required DateTime dueOn,
    required int intervalDays,
    required ReviewRating rating,
    DateTime? examOn,
    DueCount? dueCount,
    int dailyLimit = 0,
  }) {
    final scheduled = max(1, intervalDays);
    final elapsed = max(1, ScheduleDay.between(lastOn, today));
    final early = today.isBefore(dueOn);
    final success = rating == ReviewRating.good || rating == ReviewRating.easy;
    final credited = early ? elapsed : max(scheduled, elapsed);

    final interval = switch (rating) {
      ReviewRating.again => 1,
      ReviewRating.hard => () {
        final base = early ? elapsed : scheduled;
        return min(ladder.last, max(base + 1, (base * 1.2).round()));
      }(),
      ReviewRating.good => _rungAbove(credited, skip: 0),
      ReviewRating.easy => _rungAbove(credited, skip: 1),
    };

    var due = ScheduleDay.add(today, interval);
    // Reviewing ahead of time never pulls a well-known lesson closer.
    if (early && success && dueOn.isAfter(due)) due = dueOn;
    due = _capForExam(due, today, examOn);
    if (dueCount != null && dailyLimit > 0) {
      due = _spread(due, today, examOn, dueCount, dailyLimit);
    }
    return (dueOn: due, intervalDays: ScheduleDay.between(today, due));
  }

  static int _rungAbove(int days, {required int skip}) {
    final index = ladder.indexWhere((rung) => rung > days);
    if (index < 0) return ladder.last;
    return ladder[min(index + skip, ladder.length - 1)];
  }

  /// Latest day the next review may fall on before [examOn], or null when
  /// the exam is past or too close to plan around.
  static DateTime? examDeadline(DateTime today, DateTime? examOn) {
    if (examOn == null) return null;
    final left = ScheduleDay.between(today, examOn);
    if (left < 2) return null;
    return ScheduleDay.add(today, max(1, (left * examGapFraction).floor()));
  }

  static DateTime _capForExam(DateTime due, DateTime today, DateTime? examOn) {
    final latest = examDeadline(today, examOn);
    return latest != null && due.isAfter(latest) ? latest : due;
  }

  /// Moves a long gap by a few days when its day is already full.
  static DateTime _spread(
    DateTime due,
    DateTime today,
    DateTime? examOn,
    DueCount dueCount,
    int dailyLimit,
  ) {
    final gap = ScheduleDay.between(today, due);
    var bestLoad = dueCount(due);
    if (gap < 7 || bestLoad < dailyLimit) return due;
    final window = min(7, max(1, gap ~/ 10));
    final beforeExam = examOn != null && due.isBefore(examOn);
    var best = due;
    for (var offset = 1; offset <= window; offset++) {
      for (final day in [
        ScheduleDay.add(due, -offset),
        ScheduleDay.add(due, offset),
      ]) {
        if (!day.isAfter(today)) continue;
        if (beforeExam && !day.isBefore(examOn)) continue;
        final load = dueCount(day);
        if (load < bestLoad) {
          best = day;
          bestLoad = load;
        }
      }
    }
    return best;
  }
}
