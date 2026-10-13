import 'dart:math';

import 'schedule_day.dart';

/// Event kinds in `study_schedule_events`.
abstract final class ScheduleEventKind {
  static const start = 'start';
  static const review = 'review';
  static const reschedule = 'reschedule';
}

/// A scheduled lesson with its current due date.
class ScheduleEntry {
  const ScheduleEntry({
    required this.lessonId,
    required this.lessonName,
    required this.subjectId,
    required this.subjectName,
    required this.paused,
    required this.dueOn,
    required this.intervalDays,
    required this.lastOn,
    required this.reviewCount,
    this.examOn,
  });

  final String lessonId;
  final String lessonName;
  final String subjectId;
  final String subjectName;
  final DateTime? examOn;
  final bool paused;
  final DateTime dueOn;
  final int intervalDays;

  /// Day of the latest start, review or date change.
  final DateTime lastOn;
  final int reviewCount;

  bool isDue(DateTime today) => !paused && !dueOn.isAfter(today);

  int overdueDays(DateTime today) =>
      max(0, ScheduleDay.between(dueOn, today));
}

/// The Study Schedule list for one day.
class SchedulePlan {
  const SchedulePlan({
    required this.today,
    required this.overflow,
    required this.upcoming,
    required this.paused,
  });

  /// Due reviews within the daily limit, most urgent first.
  final List<ScheduleEntry> today;

  /// Due reviews beyond the daily limit; they can wait a day.
  final List<ScheduleEntry> overflow;
  final List<ScheduleEntry> upcoming;
  final List<ScheduleEntry> paused;

  int get dueCount => today.length + overflow.length;
  bool get isEmpty =>
      today.isEmpty && overflow.isEmpty && upcoming.isEmpty && paused.isEmpty;

  /// Exams within this many days put their lessons first.
  static const examPriorityDays = 14;

  factory SchedulePlan.build(
    List<ScheduleEntry> entries, {
    required DateTime today,
    required int dailyLimit,
  }) {
    int byName(ScheduleEntry a, ScheduleEntry b) {
      final subject = a.subjectName.toLowerCase().compareTo(
        b.subjectName.toLowerCase(),
      );
      return subject != 0
          ? subject
          : a.lessonName.toLowerCase().compareTo(b.lessonName.toLowerCase());
    }

    int? examIn(ScheduleEntry e) {
      if (e.examOn == null) return null;
      final days = ScheduleDay.between(today, e.examOn!);
      return days >= 0 && days <= examPriorityDays ? days : null;
    }

    final due = entries.where((e) => e.isDue(today)).toList()
      ..sort((a, b) {
        final examA = examIn(a), examB = examIn(b);
        if (examA != examB) {
          if (examA == null) return 1;
          if (examB == null) return -1;
          return examA.compareTo(examB);
        }
        final urgency = (b.overdueDays(today) / max(1, b.intervalDays))
            .compareTo(a.overdueDays(today) / max(1, a.intervalDays));
        if (urgency != 0) return urgency;
        final day = a.dueOn.compareTo(b.dueOn);
        return day != 0 ? day : byName(a, b);
      });
    final limit = dailyLimit <= 0 ? due.length : min(dailyLimit, due.length);
    return SchedulePlan(
      today: due.sublist(0, limit),
      overflow: due.sublist(limit),
      upcoming:
          entries.where((e) => !e.paused && e.dueOn.isAfter(today)).toList()
            ..sort((a, b) {
              final day = a.dueOn.compareTo(b.dueOn);
              return day != 0 ? day : byName(a, b);
            }),
      paused: entries.where((e) => e.paused).toList()..sort(byName),
    );
  }
}
