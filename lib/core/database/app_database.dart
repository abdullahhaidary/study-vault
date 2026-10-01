import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Classes table — top-level study containers.
///
/// Data class is [StudyClass] (Drift cannot generate a type named `Class`).
@DataClassName('StudyClass')
class Classes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Optional grouping of subjects within a class.
class SubjectGroups extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Subjects table — belong to a Class, optionally to a SubjectGroup.
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get subjectGroupId =>
      text().nullable().references(SubjectGroups, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Optional grouping of lessons within a subject.
class LessonGroups extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lessons table — belong to a Subject, optionally to a LessonGroup.
class Lessons extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get lessonGroupId =>
      text().nullable().references(LessonGroups, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local study materials (PDFs / images) attached to a lesson.
class LessonMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text().references(Lessons, #id)();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get originalFileName => text()();
  TextColumn get storedFileName => text()();
  TextColumn get mimeType =>
      text().withDefault(const Constant('application/pdf'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Study Pins attached to a PDF page or image resource.
///
/// [pinType] is `point` (tap marker) or `text` (PDF text selection).
/// Text pins store geometry in [StudyPinTextRanges]; [xRatio]/[yRatio] still
/// hold an anchor (first range center) for ordering / scroll helpers.
class StudyPins extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId => text().references(LessonMaterials, #id)();

  /// `point` or `text`. Existing rows migrate to `point`.
  TextColumn get pinType => text().withDefault(const Constant('point'))();

  /// 1-based PDF page number; null for image resources.
  IntColumn get pageNumber => integer().nullable()();

  /// Normalized X position within the page/image (0–1, left → right).
  RealColumn get xRatio => real()();

  /// Normalized Y position within the page/image (0–1, top → bottom).
  RealColumn get yRatio => real()();
  TextColumn get shortText => text().withLength(min: 1, max: 500)();

  /// Plain-text full explanation for now; reserved for richer formats later.
  TextColumn get fullExplanation => text().nullable()();

  /// Snapshot of the PDF selection for text pins (display context).
  TextColumn get selectedText => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Reserved for future sync soft-delete; unused by current hard-delete UI.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Normalized highlight rectangles for a text Study Pin.
///
/// One text annotation may have many rows (multi-line / multi-word selection).
class StudyPinTextRanges extends Table {
  TextColumn get id => text()();
  TextColumn get studyPinId => text().references(StudyPins, #id)();
  IntColumn get pageNumber => integer()();
  RealColumn get xRatio => real()();
  RealColumn get yRatio => real()();
  RealColumn get widthRatio => real()();
  RealColumn get heightRatio => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Classes,
    SubjectGroups,
    Subjects,
    LessonGroups,
    Lessons,
    LessonMaterials,
    StudyPins,
    StudyPinTextRanges,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Useful for tests — inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(subjectGroups);
        await m.createTable(lessonGroups);
        await m.createTable(lessons);
        await m.addColumn(subjects, subjects.subjectGroupId);
        await m.addColumn(subjects, subjects.sortOrder);
      }
      if (from < 3) {
        await m.createTable(lessonMaterials);
      }
      if (from < 4) {
        await m.createTable(studyPins);
      }
      if (from < 5) {
        await m.addColumn(studyPins, studyPins.pinType);
        await m.addColumn(studyPins, studyPins.selectedText);
        await m.createTable(studyPinTextRanges);
        // Backfill: any pre-v5 pin is a point pin (SQLite default covers
        // new rows; explicit update keeps semantics obvious in tests).
        await customStatement(
          "UPDATE study_pins SET pin_type = 'point' "
          "WHERE pin_type IS NULL OR pin_type = ''",
        );
      }
    },
  );

  // ── Classes ──────────────────────────────────────────────

  Stream<List<StudyClass>> watchAllClasses() {
    return (select(
      classes,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<StudyClass?> getClassById(String id) {
    return (select(classes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<StudyClass?> watchClassById(String id) {
    return (select(classes)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> countSubjectsForClass(String classId) async {
    final count = countAll();
    final query = selectOnly(subjects)
      ..addColumns([count])
      ..where(subjects.classId.equals(classId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> insertClass(ClassesCompanion entry) {
    return into(classes).insert(entry);
  }

  // ── Subject Groups ───────────────────────────────────────

  Stream<List<SubjectGroup>> watchSubjectGroupsForClass(String classId) {
    return (select(subjectGroups)
          ..where((t) => t.classId.equals(classId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<SubjectGroup?> getSubjectGroupById(String id) {
    return (select(
      subjectGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> nextSubjectGroupSortOrder(String classId) async {
    final maxExpr = subjectGroups.sortOrder.max();
    final query = selectOnly(subjectGroups)
      ..addColumns([maxExpr])
      ..where(subjectGroups.classId.equals(classId));
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertSubjectGroup(SubjectGroupsCompanion entry) {
    return into(subjectGroups).insert(entry);
  }

  Future<void> updateSubjectGroup(SubjectGroup group) {
    return update(subjectGroups).replace(group);
  }

  /// Unassigns subjects from the group, then deletes the group.
  Future<void> deleteSubjectGroup(String groupId) async {
    await (update(subjects)..where((t) => t.subjectGroupId.equals(groupId)))
        .write(const SubjectsCompanion(subjectGroupId: Value(null)));
    await (delete(subjectGroups)..where((t) => t.id.equals(groupId))).go();
  }

  // ── Subjects ─────────────────────────────────────────────

  Stream<List<Subject>> watchSubjectsForClass(String classId) {
    return (select(subjects)
          ..where((t) => t.classId.equals(classId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<Subject?> getSubjectById(String id) {
    return (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Subject?> watchSubjectById(String id) {
    return (select(
      subjects,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> nextSubjectSortOrder(String classId) async {
    final maxExpr = subjects.sortOrder.max();
    final query = selectOnly(subjects)
      ..addColumns([maxExpr])
      ..where(subjects.classId.equals(classId));
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertSubject(SubjectsCompanion entry) {
    return into(subjects).insert(entry);
  }

  Future<void> updateSubject(Subject subject) {
    return update(subjects).replace(subject);
  }

  // ── Lesson Groups ────────────────────────────────────────

  Stream<List<LessonGroup>> watchLessonGroupsForSubject(String subjectId) {
    return (select(lessonGroups)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<LessonGroup?> getLessonGroupById(String id) {
    return (select(
      lessonGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> nextLessonGroupSortOrder(String subjectId) async {
    final maxExpr = lessonGroups.sortOrder.max();
    final query = selectOnly(lessonGroups)
      ..addColumns([maxExpr])
      ..where(lessonGroups.subjectId.equals(subjectId));
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertLessonGroup(LessonGroupsCompanion entry) {
    return into(lessonGroups).insert(entry);
  }

  Future<void> updateLessonGroup(LessonGroup group) {
    return update(lessonGroups).replace(group);
  }

  /// Unassigns lessons from the group, then deletes the group.
  Future<void> deleteLessonGroup(String groupId) async {
    await (update(lessons)..where((t) => t.lessonGroupId.equals(groupId)))
        .write(const LessonsCompanion(lessonGroupId: Value(null)));
    await (delete(lessonGroups)..where((t) => t.id.equals(groupId))).go();
  }

  // ── Lessons ──────────────────────────────────────────────

  Stream<List<Lesson>> watchLessonsForSubject(String subjectId) {
    return (select(lessons)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<Lesson?> getLessonById(String id) {
    return (select(lessons)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> nextLessonSortOrder(String subjectId) async {
    final maxExpr = lessons.sortOrder.max();
    final query = selectOnly(lessons)
      ..addColumns([maxExpr])
      ..where(lessons.subjectId.equals(subjectId));
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertLesson(LessonsCompanion entry) {
    return into(lessons).insert(entry);
  }

  Future<void> updateLesson(Lesson lesson) {
    return update(lessons).replace(lesson);
  }

  Stream<Lesson?> watchLessonById(String id) {
    return (select(lessons)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  // ── Lesson Materials ─────────────────────────────────────

  Stream<List<LessonMaterial>> watchMaterialsForLesson(String lessonId) {
    return (select(lessonMaterials)
          ..where((t) => t.lessonId.equals(lessonId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<LessonMaterial?> getMaterialById(String id) {
    return (select(
      lessonMaterials,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> nextMaterialSortOrder(String lessonId) async {
    final maxExpr = lessonMaterials.sortOrder.max();
    final query = selectOnly(lessonMaterials)
      ..addColumns([maxExpr])
      ..where(lessonMaterials.lessonId.equals(lessonId));
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertLessonMaterial(LessonMaterialsCompanion entry) {
    return into(lessonMaterials).insert(entry);
  }

  Future<void> deleteLessonMaterial(String id) async {
    final pinIds = await (select(
      studyPins,
    )..where((t) => t.resourceId.equals(id))).map((row) => row.id).get();
    if (pinIds.isNotEmpty) {
      await (delete(
        studyPinTextRanges,
      )..where((t) => t.studyPinId.isIn(pinIds))).go();
    }
    await (delete(studyPins)..where((t) => t.resourceId.equals(id))).go();
    await (delete(lessonMaterials)..where((t) => t.id.equals(id))).go();
  }

  // ── Study Pins ───────────────────────────────────────────

  Stream<List<StudyPin>> watchStudyPinsForResource(String resourceId) {
    return (select(studyPins)
          ..where((t) => t.resourceId.equals(resourceId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.pageNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Future<StudyPin?> getStudyPinById(String id) {
    return (select(studyPins)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<StudyPin?> watchStudyPinById(String id) {
    return (select(
      studyPins,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> insertStudyPin(StudyPinsCompanion entry) {
    return into(studyPins).insert(entry);
  }

  Future<void> updateStudyPin(StudyPin pin) {
    return update(studyPins).replace(pin);
  }

  Future<void> deleteStudyPin(String id) async {
    await (delete(
      studyPinTextRanges,
    )..where((t) => t.studyPinId.equals(id))).go();
    await (delete(studyPins)..where((t) => t.id.equals(id))).go();
  }

  // ── Study Pin Text Ranges ────────────────────────────────

  Stream<List<StudyPinTextRange>> watchTextRangesForResource(
    String resourceId,
  ) {
    final query =
        select(studyPinTextRanges).join([
            innerJoin(
              studyPins,
              studyPins.id.equalsExp(studyPinTextRanges.studyPinId),
            ),
          ])
          ..where(
            studyPins.resourceId.equals(resourceId) &
                studyPins.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(studyPinTextRanges.pageNumber),
            OrderingTerm.asc(studyPinTextRanges.sortOrder),
          ]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(studyPinTextRanges)).toList(),
    );
  }

  Future<List<StudyPinTextRange>> getTextRangesForPin(String studyPinId) {
    return (select(studyPinTextRanges)
          ..where((t) => t.studyPinId.equals(studyPinId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.pageNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
  }

  Stream<List<StudyPinTextRange>> watchTextRangesForPin(String studyPinId) {
    return (select(studyPinTextRanges)
          ..where((t) => t.studyPinId.equals(studyPinId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.pageNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
  }

  Future<void> insertStudyPinTextRange(StudyPinTextRangesCompanion entry) {
    return into(studyPinTextRanges).insert(entry);
  }

  /// Inserts a Study Pin and its text ranges atomically.
  Future<void> insertTextStudyPin({
    required StudyPinsCompanion pin,
    required List<StudyPinTextRangesCompanion> ranges,
  }) {
    return transaction(() async {
      await into(studyPins).insert(pin);
      for (final range in ranges) {
        await into(studyPinTextRanges).insert(range);
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'study_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
