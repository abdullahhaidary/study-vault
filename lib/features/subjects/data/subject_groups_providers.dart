import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

/// Watches subject groups for a class, ordered by [sortOrder].
final subjectGroupsForClassProvider =
    StreamProvider.family<List<SubjectGroup>, String>((ref, classId) {
      final db = ref.watch(databaseProvider);
      return db.watchSubjectGroupsForClass(classId);
    });

Future<void> createSubjectGroup(
  WidgetRef ref, {
  required String classId,
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextSubjectGroupSortOrder(classId);

  await db.insertSubjectGroup(
    SubjectGroupsCompanion.insert(
      id: _uuid.v4(),
      classId: classId,
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

Future<void> updateSubjectGroupDetails(
  WidgetRef ref, {
  required SubjectGroup group,
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateSubjectGroup(
    group.copyWith(
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteSubjectGroup(WidgetRef ref, String groupId) async {
  final db = ref.read(databaseProvider);
  await db.deleteSubjectGroup(groupId);
}
