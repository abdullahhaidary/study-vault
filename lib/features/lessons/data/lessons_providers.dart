import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

/// Watches lessons belonging to a subject, ordered by [sortOrder].
final lessonsForSubjectProvider =
    StreamProvider.family<List<Lesson>, String>((ref, subjectId) {
  final db = ref.watch(databaseProvider);
  return db.watchLessonsForSubject(subjectId);
});

/// Watches a single lesson by id.
final lessonByIdProvider =
    StreamProvider.family<Lesson?, String>((ref, lessonId) {
  final db = ref.watch(databaseProvider);
  return db.watchLessonById(lessonId);
});

Future<void> createLesson(
  WidgetRef ref, {
  required String subjectId,
  required String name,
  String? description,
  String? lessonGroupId,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextLessonSortOrder(subjectId);

  await db.insertLesson(
    LessonsCompanion.insert(
      id: _uuid.v4(),
      subjectId: subjectId,
      lessonGroupId: Value(lessonGroupId),
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> updateLessonDetails(
  WidgetRef ref, {
  required Lesson lesson,
  required String name,
  String? description,
  String? lessonGroupId,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateLesson(
    lesson.copyWith(
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      lessonGroupId: Value(lessonGroupId),
      updatedAt: DateTime.now(),
    ),
  );
}
