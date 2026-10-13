import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../study_schedule/data/study_schedule_providers.dart';
import '../domain/lesson_progress.dart';

/// Watches lessons marked Studying, newest activity first.
final continueStudyingLessonsProvider = StreamProvider<List<Lesson>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchStudyingLessons();
});

/// Marking a lesson Reviewed or Mastered adds it to the Study Schedule.
/// Returns true when it was newly scheduled.
Future<bool> setLessonProgress(
  WidgetRef ref, {
  required Lesson lesson,
  required LessonProgressStatus status,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateLessonProgress(
    lessonId: lesson.id,
    progressStatus: status.storageValue,
    touchLastStudied: status == LessonProgressStatus.studying,
  );
  if (status != LessonProgressStatus.reviewed &&
      status != LessonProgressStatus.mastered) {
    return false;
  }
  return ref
      .read(studyScheduleRepositoryProvider)
      .enroll(lesson.id, mastered: status == LessonProgressStatus.mastered);
}

/// Call when the user performs meaningful study activity for a lesson.
Future<void> recordLessonStudyActivity(
  WidgetRef ref, {
  required String lessonId,
}) async {
  final db = ref.read(databaseProvider);
  await db.recordLessonStudyActivity(lessonId);
}

/// Resolves lesson id from a material and records study activity.
Future<void> recordMaterialStudyActivity(
  WidgetRef ref, {
  required String materialId,
}) async {
  final db = ref.read(databaseProvider);
  final material = await db.getMaterialById(materialId);
  if (material == null) return;
  await db.recordLessonStudyActivity(material.lessonId);
}

/// Filters a lesson list by progress (client-side for subject lesson lists).
List<Lesson> filterLessonsByProgress(
  List<Lesson> lessons,
  LessonProgressStatus? filter,
) {
  if (filter == null) return lessons;
  return lessons
      .where(
        (l) => LessonProgressStatus.fromStorage(l.progressStatus) == filter,
      )
      .toList();
}
