import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

/// Watches all classes, ordered by creation date (newest first).
final classesProvider = StreamProvider<List<StudyClass>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllClasses();
});

/// Watches a single class by id.
final classByIdProvider = StreamProvider.family<StudyClass?, String>((
  ref,
  classId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchClassById(classId);
});

/// Subject count for a given class (re-reads whenever subjects change).
final subjectCountProvider = StreamProvider.family<int, String>((ref, classId) {
  final db = ref.watch(databaseProvider);
  // Re-emit count whenever the subjects stream for this class updates.
  return db.watchSubjectsForClass(classId).asyncMap((_) {
    return db.countSubjectsForClass(classId);
  });
});

final subjectCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  final count = db.subjects.id.count();
  final query = db.selectOnly(db.subjects)
    ..addColumns([db.subjects.classId, count])
    ..groupBy([db.subjects.classId]);
  return query.watch().map(
    (rows) => {
      for (final row in rows)
        if (row.read(db.subjects.classId) != null)
          row.read(db.subjects.classId)!: row.read(count) ?? 0,
    },
  );
});

/// Creates a new class and persists it locally.
Future<void> createClass(
  WidgetRef ref, {
  required String name,
  String? description,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();

  await db.insertClass(
    ClassesCompanion.insert(
      id: _uuid.v4(),
      name: name.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      createdAt: now,
      updatedAt: now,
    ),
  );
}
