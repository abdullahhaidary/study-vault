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

/// Local study materials (currently PDFs) attached to a lesson.
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

@DriftDatabase(
  tables: [
    Classes,
    SubjectGroups,
    Subjects,
    LessonGroups,
    Lessons,
    LessonMaterials,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Useful for tests — inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

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
        },
      );

  // ── Classes ──────────────────────────────────────────────

  Stream<List<StudyClass>> watchAllClasses() {
    return (select(classes)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
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
    return (select(subjectGroups)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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
    return (select(subjects)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
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
    return (select(lessonGroups)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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
    return (select(lessonMaterials)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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

  Future<void> deleteLessonMaterial(String id) {
    return (delete(lessonMaterials)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'study_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
