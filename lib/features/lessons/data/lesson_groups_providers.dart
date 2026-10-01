import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

/// Watches lesson groups for a subject, ordered by [sortOrder].
final lessonGroupsForSubjectProvider =
    StreamProvider.family<List<LessonGroup>, String>((ref, subjectId) {
  final db = ref.watch(databaseProvider);
  return db.watchLessonGroupsForSubject(subjectId);
});

Future<void> createLessonGroup(
  WidgetRef ref, {
  required String subjectId,
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextLessonGroupSortOrder(subjectId);

  await db.insertLessonGroup(
    LessonGroupsCompanion.insert(
      id: _uuid.v4(),
      subjectId: subjectId,
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

Future<void> updateLessonGroupDetails(
  WidgetRef ref, {
  required LessonGroup group,
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateLessonGroup(
    group.copyWith(
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteLessonGroup(WidgetRef ref, String groupId) async {
  final db = ref.read(databaseProvider);
  await db.deleteLessonGroup(groupId);
}
