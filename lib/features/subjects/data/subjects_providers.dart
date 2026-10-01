import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

/// Watches subjects belonging to a class.
final subjectsForClassProvider =
    StreamProvider.family<List<Subject>, String>((ref, classId) {
  final db = ref.watch(databaseProvider);
  return db.watchSubjectsForClass(classId);
});

/// Watches a single subject by id.
final subjectByIdProvider =
    StreamProvider.family<Subject?, String>((ref, subjectId) {
  final db = ref.watch(databaseProvider);
  return db.watchSubjectById(subjectId);
});

/// Creates a new subject inside a class.
Future<void> createSubject(
  WidgetRef ref, {
  required String classId,
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();

  await db.insertSubject(
    SubjectsCompanion.insert(
      id: _uuid.v4(),
      classId: classId,
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      createdAt: now,
      updatedAt: now,
    ),
  );
}
