import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/schedule_day.dart';
import '../domain/schedule_models.dart';
import 'study_schedule_repository.dart';

final studyScheduleRepositoryProvider = Provider<StudyScheduleRepository>((
  ref,
) {
  return StudyScheduleRepository(ref.watch(databaseProvider));
});

final scheduleEntriesProvider = StreamProvider<List<ScheduleEntry>>((ref) {
  return ref.watch(studyScheduleRepositoryProvider).watchEntries();
});

/// Device setting: how many due reviews make up one day's plan (0 = all).
abstract final class ScheduleDailyLimit {
  static const key = 'study_schedule_daily_limit';
  static const defaultValue = 10;
  static const options = [5, 10, 15, 20, 30, 0];

  static String label(int value) => value == 0 ? 'No limit' : '$value per day';
}

final scheduleDailyLimitProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(ScheduleDailyLimit.key) ??
      ScheduleDailyLimit.defaultValue;
});

Future<void> setScheduleDailyLimit(WidgetRef ref, int value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(ScheduleDailyLimit.key, value);
  ref.invalidate(scheduleDailyLimitProvider);
}

final schedulePlanProvider = Provider<AsyncValue<SchedulePlan>>((ref) {
  final limit =
      ref.watch(scheduleDailyLimitProvider).valueOrNull ??
      ScheduleDailyLimit.defaultValue;
  return ref
      .watch(scheduleEntriesProvider)
      .whenData(
        (entries) => SchedulePlan.build(
          entries,
          today: ScheduleDay.today(),
          dailyLimit: limit,
        ),
      );
});

final scheduleDueCountProvider = Provider<int>((ref) {
  return ref.watch(schedulePlanProvider).valueOrNull?.dueCount ?? 0;
});

final lessonScheduleEntryProvider = Provider.family<ScheduleEntry?, String>((
  ref,
  lessonId,
) {
  final entries = ref.watch(scheduleEntriesProvider).valueOrNull;
  return entries?.where((e) => e.lessonId == lessonId).firstOrNull;
});

/// Lessons marked Reviewed/Mastered before they were scheduled.
final unscheduledReviewedLessonsProvider = FutureProvider<List<Lesson>>((ref) {
  ref.watch(scheduleEntriesProvider);
  return ref
      .watch(studyScheduleRepositoryProvider)
      .unscheduledReviewedLessons();
});

final lessonSummariesProvider =
    FutureProvider.family<List<LessonSummary>, String>((ref, lessonId) {
      return ref
          .watch(studyScheduleRepositoryProvider)
          .lessonSummaries(lessonId);
    });
