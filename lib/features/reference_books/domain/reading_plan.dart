import 'dart:math' as math;

enum BookLinkPriority {
  must('must', 'Must read', 1.0),
  skim('skim', 'Skim', 0.4),
  optional('optional', 'Optional', 0.0);

  const BookLinkPriority(this.storageValue, this.label, this.weight);
  final String storageValue;
  final String label;

  /// Share of full reading effort a page at this priority costs.
  final double weight;

  static BookLinkPriority fromStorage(String? value) =>
      values.firstWhere((p) => p.storageValue == value, orElse: () => skim);
}

/// One page range the plan schedules.
class PlanRange {
  const PlanRange({
    required this.id,
    required this.lectureTitle,
    required this.startPage,
    required this.endPage,
    required this.priority,
    this.done = false,
  });

  final String id;
  final String lectureTitle;
  final int startPage;
  final int endPage;
  final BookLinkPriority priority;
  final bool done;

  int get pages => endPage - startPage + 1;
  double get effort => pages * priority.weight;
}

class PlanDay {
  const PlanDay(this.date, this.ranges);
  final DateTime date;
  final List<PlanRange> ranges;

  double get effort => ranges.fold(0, (sum, r) => sum + r.effort);
}

class ReadingPlan {
  const ReadingPlan({
    required this.days,
    required this.mustPages,
    required this.skimPages,
    required this.remainingEffort,
    required this.effortPerDay,
  });

  final List<PlanDay> days;
  final int mustPages;
  final int skimPages;
  final double remainingEffort;
  final double effortPerDay;

  /// Estimated hours at [pagesPerHour] full-reading pages.
  double hours(double pagesPerHour) => remainingEffort / pagesPerHour;
}

/// Spreads unfinished ranges over the days until [examDate], in lecture
/// order, keeping each range on a single day.
ReadingPlan buildReadingPlan({
  required List<PlanRange> ranges,
  required DateTime today,
  required DateTime examDate,
  bool includeOptional = false,
}) {
  final wanted = [
    for (final r in ranges)
      if (includeOptional || r.priority != BookLinkPriority.optional) r,
  ];
  final pending = [
    for (final r in wanted)
      if (!r.done) r,
  ];
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(examDate.year, examDate.month, examDate.day);
  final dayCount = math.max(1, end.difference(start).inDays);
  final remaining = pending.fold<double>(
    0,
    (sum, r) => sum + math.max(r.effort, r.pages * 0.1),
  );
  final perDay = remaining / dayCount;
  final days = <PlanDay>[];
  var current = <PlanRange>[];
  var load = 0.0;
  for (final range in pending) {
    final cost = math.max(range.effort, range.pages * 0.1);
    if (current.isNotEmpty &&
        load + cost > perDay * 1.15 &&
        days.length < dayCount - 1) {
      days.add(PlanDay(start.add(Duration(days: days.length)), current));
      current = [];
      load = 0;
    }
    current.add(range);
    load += cost;
  }
  if (current.isNotEmpty) {
    days.add(PlanDay(start.add(Duration(days: days.length)), current));
  }
  return ReadingPlan(
    days: days,
    mustPages: wanted
        .where((r) => r.priority == BookLinkPriority.must)
        .fold(0, (s, r) => s + r.pages),
    skimPages: wanted
        .where((r) => r.priority == BookLinkPriority.skim)
        .fold(0, (s, r) => s + r.pages),
    remainingEffort: remaining,
    effortPerDay: perDay,
  );
}
