import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../features/study_pins/domain/study_note_codec.dart';
import '../storage/study_vault_paths.dart';
import 'built_in_data.dart';

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

/// Optional study-meaning categories for pins (Definition, Formula, …).
class StudyPinCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Study Pins attached to a PDF page or image resource.
///
/// [pinType] is `point` (tap marker) or `text` (PDF text selection).
/// [categoryId] is optional study meaning (Definition, Formula, …).
/// Text pins store geometry in [StudyPinTextRanges]; [xRatio]/[yRatio] still
/// hold an anchor (first range center) for ordering / scroll helpers.
class StudyPins extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId => text().references(LessonMaterials, #id)();

  /// `point` or `text`. Existing rows migrate to `point`.
  TextColumn get pinType => text().withDefault(const Constant('point'))();

  /// Optional study category (not the point/text annotation type).
  TextColumn get categoryId =>
      text().nullable().references(StudyPinCategories, #id)();

  /// 1-based PDF page number; null for image resources.
  IntColumn get pageNumber => integer().nullable()();

  /// Normalized X position within the page/image (0–1, left → right).
  RealColumn get xRatio => real()();

  /// Normalized Y position within the page/image (0–1, top → bottom).
  RealColumn get yRatio => real()();
  TextColumn get shortText => text().withLength(min: 1, max: 500)();

  /// Full note: Quill Delta JSON (or legacy plain text).
  TextColumn get fullExplanation => text().nullable()();

  /// Plain-text extraction of [fullExplanation] for local search.
  TextColumn get fullExplanationPlainText => text().nullable()();

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

/// Generic favorites / bookmarks across study entities.
class Favorites extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {entityType, entityId},
  ];
}

/// A Study Review Mode session (lesson / material / subject / favorites).
class StudyReviewSessions extends Table {
  TextColumn get id => text()();

  /// `lesson`, `material`, `subject`, or `favorites`.
  TextColumn get scopeType => text()();

  /// Scope entity id; null when [scopeType] is `favorites`.
  TextColumn get scopeId => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get totalItems => integer()();
  IntColumn get reviewedItems => integer().withDefault(const Constant(0))();
  BoolColumn get shuffle => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual recall ratings within a review session.
///
/// Cascades when the Study Pin is deleted (history option A).
class StudyReviewEvents extends Table {
  TextColumn get id => text()();
  TextColumn get studyPinId =>
      text().references(StudyPins, #id, onDelete: KeyAction.cascade)();
  TextColumn get sessionId => text().references(
    StudyReviewSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// `again`, `hard`, `good`, or `easy`.
  TextColumn get rating => text()();
  DateTimeColumn get reviewedAt => dateTime()();
  IntColumn get responseTimeMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

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
    StudyPinCategories,
    StudyPins,
    StudyPinTextRanges,
    Favorites,
    StudyReviewSessions,
    StudyReviewEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Useful for tests — inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await seedBuiltInCategories();
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
        await customStatement(
          "UPDATE study_pins SET pin_type = 'point' "
          "WHERE pin_type IS NULL OR pin_type = ''",
        );
      }
      if (from < 6) {
        await m.createTable(studyPinCategories);
        await m.createTable(favorites);
        await m.addColumn(studyPins, studyPins.categoryId);
        await m.addColumn(studyPins, studyPins.fullExplanationPlainText);
        await seedBuiltInCategories();
        await backfillFullExplanationPlainText();
      }
      if (from < 7) {
        await m.createTable(studyReviewSessions);
        await m.createTable(studyReviewEvents);
      }
    },
  );

  /// Inserts built-in categories once (idempotent by primary key).
  Future<void> seedBuiltInCategories() async {
    final now = DateTime.now();
    for (final seed in BuiltInPinCategories.seeds) {
      final existing = await (select(
        studyPinCategories,
      )..where((t) => t.id.equals(seed.id))).getSingleOrNull();
      if (existing != null) continue;
      await into(studyPinCategories).insert(
        StudyPinCategoriesCompanion.insert(
          id: seed.id,
          name: seed.name,
          colorValue: seed.colorValue,
          iconKey: Value(seed.iconKey),
          sortOrder: Value(seed.sortOrder),
          isSystem: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  /// Populates searchable plain text from existing fullExplanation values.
  Future<void> backfillFullExplanationPlainText() async {
    final pins = await select(studyPins).get();
    for (final pin in pins) {
      if (pin.fullExplanation == null || pin.fullExplanation!.isEmpty) {
        continue;
      }
      final plain = StudyNoteCodec.plainTextPreview(pin.fullExplanation);
      await (update(studyPins)..where((t) => t.id.equals(pin.id))).write(
        StudyPinsCompanion(
          fullExplanationPlainText: Value(plain.isEmpty ? null : plain),
        ),
      );
    }
  }

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
      await deleteReviewEventsForPins(pinIds);
      await deleteFavoritesForEntities(FavoriteEntityType.studyPin, pinIds);
    }
    await (delete(studyPins)..where((t) => t.resourceId.equals(id))).go();
    await deleteFavoritesForEntities(FavoriteEntityType.material, [id]);
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
    await deleteReviewEventsForPins([id]);
    await deleteFavoritesForEntities(FavoriteEntityType.studyPin, [id]);
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

  // ── Categories ───────────────────────────────────────────

  Stream<List<StudyPinCategory>> watchAllCategories() {
    return (select(
      studyPinCategories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
  }

  Future<List<StudyPinCategory>> getAllCategories() {
    return (select(
      studyPinCategories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
  }

  Future<StudyPinCategory?> getCategoryById(String id) {
    return (select(
      studyPinCategories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ── Favorites ────────────────────────────────────────────

  Stream<List<Favorite>> watchAllFavorites() {
    return (select(
      favorites,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Stream<List<Favorite>> watchFavoritesOfType(String entityType) {
    return (select(favorites)
          ..where((t) => t.entityType.equals(entityType))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<bool> watchIsFavorite(String entityType, String entityId) {
    return (select(favorites)..where(
          (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
        ))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  Future<bool> isFavorite(String entityType, String entityId) async {
    final row =
        await (select(favorites)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.entityId.equals(entityId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> addFavorite({
    required String id,
    required String entityType,
    required String entityId,
  }) async {
    final exists = await isFavorite(entityType, entityId);
    if (exists) return;
    await into(favorites).insert(
      FavoritesCompanion.insert(
        id: id,
        entityType: entityType,
        entityId: entityId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeFavorite(String entityType, String entityId) {
    return (delete(favorites)..where(
          (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
        ))
        .go();
  }

  Future<void> deleteFavoritesForEntities(
    String entityType,
    List<String> entityIds,
  ) async {
    if (entityIds.isEmpty) return;
    await (delete(favorites)..where(
          (t) => t.entityType.equals(entityType) & t.entityId.isIn(entityIds),
        ))
        .go();
  }

  Future<Set<String>> favoriteIdsOfType(String entityType) async {
    final rows = await (select(
      favorites,
    )..where((t) => t.entityType.equals(entityType))).get();
    return rows.map((r) => r.entityId).toSet();
  }

  // ── Study Review ─────────────────────────────────────────

  Future<void> insertReviewSession(StudyReviewSessionsCompanion entry) {
    return into(studyReviewSessions).insert(entry);
  }

  Future<void> updateReviewSession(StudyReviewSession session) {
    return update(studyReviewSessions).replace(session);
  }

  Future<StudyReviewSession?> getReviewSessionById(String id) {
    return (select(
      studyReviewSessions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<List<StudyReviewSession>> watchRecentReviewSessions({int limit = 30}) {
    return (select(studyReviewSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> insertReviewEvent(StudyReviewEventsCompanion entry) {
    return into(studyReviewEvents).insert(entry);
  }

  Future<List<StudyReviewEvent>> getReviewEventsForSession(String sessionId) {
    return (select(studyReviewEvents)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.reviewedAt)]))
        .get();
  }

  Future<void> deleteReviewEventsForPins(List<String> pinIds) async {
    if (pinIds.isEmpty) return;
    await (delete(
      studyReviewEvents,
    )..where((t) => t.studyPinId.isIn(pinIds))).go();
  }

  /// Material ids for a lesson (ordered).
  Future<List<String>> materialIdsForLesson(String lessonId) async {
    final rows =
        await (select(lessonMaterials)
              ..where((t) => t.lessonId.equals(lessonId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map((r) => r.id).toList();
  }

  /// Lesson ids for a subject (ordered).
  Future<List<String>> lessonIdsForSubject(String subjectId) async {
    final rows =
        await (select(lessons)
              ..where((t) => t.subjectId.equals(subjectId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map((r) => r.id).toList();
  }

  /// Pins for the given material ids, stable order: material → page → sort.
  Future<List<StudyPin>> getStudyPinsForMaterialIds(
    List<String> materialIds,
  ) async {
    if (materialIds.isEmpty) return const [];
    final rows =
        await (select(studyPins)..where(
              (t) => t.resourceId.isIn(materialIds) & t.deletedAt.isNull(),
            ))
            .get();

    final materialOrder = {
      for (var i = 0; i < materialIds.length; i++) materialIds[i]: i,
    };

    rows.sort((a, b) {
      final ma = materialOrder[a.resourceId] ?? 0;
      final mb = materialOrder[b.resourceId] ?? 0;
      if (ma != mb) return ma.compareTo(mb);
      final pa = a.pageNumber ?? 0;
      final pb = b.pageNumber ?? 0;
      if (pa != pb) return pa.compareTo(pb);
      final sa = a.sortOrder ?? 0;
      final sb = b.sortOrder ?? 0;
      if (sa != sb) return sa.compareTo(sb);
      return a.createdAt.compareTo(b.createdAt);
    });
    return rows;
  }

  Future<List<LessonMaterial>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return (select(lessonMaterials)..where((t) => t.id.isIn(ids))).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await StudyVaultPaths.databaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
