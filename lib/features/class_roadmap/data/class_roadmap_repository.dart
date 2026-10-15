import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../lessons/domain/lesson_progress.dart';
import '../domain/roadmap_models.dart';

const _uuid = Uuid();

/// Ordered lesson syllabus for a class.
class ClassRoadmapRepository {
  ClassRoadmapRepository(this._db);

  final AppDatabase _db;

  Selectable<QueryRow> _stepsQuery(String classId) => _db.customSelect(
    'SELECT r.id, r.class_id, r.lesson_id, r.sort_order, r.note, '
    'l.name AS lesson_name, l.progress_status, l.subject_id, '
    's.name AS subject_name '
    'FROM class_roadmap_entries r '
    'JOIN lessons l ON l.id = r.lesson_id '
    'JOIN subjects s ON s.id = l.subject_id '
    'WHERE r.class_id = ? '
    'ORDER BY r.sort_order ASC, r.created_at ASC',
    variables: [Variable.withString(classId)],
    readsFrom: {
      _db.classRoadmapEntries,
      _db.lessons,
      _db.subjects,
    },
  );

  List<RoadmapStep> _mapSteps(List<QueryRow> rows) => [
    for (final row in rows)
      RoadmapStep(
        id: row.read<String>('id'),
        classId: row.read<String>('class_id'),
        lessonId: row.read<String>('lesson_id'),
        lessonName: row.read<String>('lesson_name'),
        subjectId: row.read<String>('subject_id'),
        subjectName: row.read<String>('subject_name'),
        progress: LessonProgressStatus.fromStorage(
          row.readNullable<String>('progress_status'),
        ),
        sortOrder: row.read<int>('sort_order'),
        note: row.readNullable<String>('note'),
      ),
  ];

  Stream<List<RoadmapStep>> watchSteps(String classId) =>
      _stepsQuery(classId).watch().map(_mapSteps);

  Future<List<RoadmapStep>> steps(String classId) async =>
      _mapSteps(await _stepsQuery(classId).get());

  /// Lessons in the class that are not on the roadmap yet.
  Future<List<RoadmapCandidate>> availableLessons(String classId) async {
    final lessons = await _db.lessonsAvailableForRoadmap(classId);
    if (lessons.isEmpty) return const [];

    final subjectIds = lessons.map((l) => l.subjectId).toSet().toList();
    final subjects = await (_db.select(
      _db.subjects,
    )..where((t) => t.id.isIn(subjectIds))).get();
    final names = {for (final s in subjects) s.id: s.name};

    return [
      for (final lesson in lessons)
        RoadmapCandidate(
          lessonId: lesson.id,
          lessonName: lesson.name,
          subjectId: lesson.subjectId,
          subjectName: names[lesson.subjectId] ?? 'Subject',
        ),
    ];
  }

  /// Adds [lessonId] at the end. Returns false if it is already listed.
  Future<bool> addLesson(String classId, String lessonId) {
    return _db.transaction(() async {
      if (await _db.getRoadmapEntry(classId, lessonId) != null) return false;
      final lesson = await _db.getLessonById(lessonId);
      if (lesson == null) return false;
      final subject = await _db.getSubjectById(lesson.subjectId);
      if (subject == null || subject.classId != classId) return false;

      final now = DateTime.now();
      await _db.insertRoadmapEntry(
        ClassRoadmapEntriesCompanion.insert(
          id: _uuid.v4(),
          classId: classId,
          lessonId: lessonId,
          sortOrder: Value(await _db.nextRoadmapSortOrder(classId)),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    });
  }

  Future<int> addLessons(String classId, List<String> lessonIds) async {
    var added = 0;
    for (final id in lessonIds) {
      if (await addLesson(classId, id)) added++;
    }
    return added;
  }

  Future<void> removeEntry(String entryId) => _db.deleteRoadmapEntry(entryId);

  /// Moves [entryId] one step toward the start of the list.
  Future<void> moveUp(String classId, String entryId) =>
      _swapNeighbor(classId, entryId, towardStart: true);

  /// Moves [entryId] one step toward the end of the list.
  Future<void> moveDown(String classId, String entryId) =>
      _swapNeighbor(classId, entryId, towardStart: false);

  Future<void> _swapNeighbor(
    String classId,
    String entryId, {
    required bool towardStart,
  }) {
    return _db.transaction(() async {
      final entries = await (_db.select(_db.classRoadmapEntries)
            ..where((t) => t.classId.equals(classId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      final index = entries.indexWhere((e) => e.id == entryId);
      if (index < 0) return;
      final neighbor = towardStart ? index - 1 : index + 1;
      if (neighbor < 0 || neighbor >= entries.length) return;

      final a = entries[index];
      final b = entries[neighbor];
      final now = DateTime.now();
      await _db.updateRoadmapEntry(
        a.copyWith(sortOrder: b.sortOrder, updatedAt: now),
      );
      await _db.updateRoadmapEntry(
        b.copyWith(sortOrder: a.sortOrder, updatedAt: now),
      );
    });
  }

  /// First step that is not yet Reviewed/Mastered, or null when finished.
  RoadmapStep? currentStep(List<RoadmapStep> steps) {
    for (final step in steps) {
      if (!step.isDone) return step;
    }
    return null;
  }
}
