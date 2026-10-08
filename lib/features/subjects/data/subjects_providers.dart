import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';

const _uuid = Uuid();

/// Watches subjects belonging to a class, ordered by [sortOrder].
final subjectsForClassProvider = StreamProvider.family<List<Subject>, String>((
  ref,
  classId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchSubjectsForClass(classId);
});

/// Watches a single subject by id.
final subjectByIdProvider = StreamProvider.family<Subject?, String>((
  ref,
  subjectId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchSubjectById(subjectId);
});

/// Creates a new subject inside a class.
Future<void> createSubject(
  WidgetRef ref, {
  required String classId,
  required String name,
  String? description,
  String? subjectGroupId,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextSubjectSortOrder(classId);

  await db.insertSubject(
    SubjectsCompanion.insert(
      id: _uuid.v4(),
      classId: classId,
      subjectGroupId: Value(subjectGroupId),
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

Future<void> updateSubjectDetails(
  WidgetRef ref, {
  required Subject subject,
  required String name,
  String? description,
  String? subjectGroupId,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateSubject(
    subject.copyWith(
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      subjectGroupId: Value(subjectGroupId),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteSubject(WidgetRef ref, {required String subjectId}) async {
  final db = ref.read(databaseProvider);
  final lessonIds = await db.deleteSubject(subjectId);
  for (final lessonId in lessonIds) {
    await MaterialStorage.deleteLessonDir(lessonId);
  }
}
