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

/// Subjects table — belong to a Class.
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Classes, Subjects])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Useful for tests — inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

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

  // ── Subjects ─────────────────────────────────────────────

  Stream<List<Subject>> watchSubjectsForClass(String classId) {
    return (select(subjects)
          ..where((t) => t.classId.equals(classId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Subject?> getSubjectById(String id) {
    return (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Subject?> watchSubjectById(String id) {
    return (select(subjects)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> insertSubject(SubjectsCompanion entry) {
    return into(subjects).insert(entry);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'study_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
