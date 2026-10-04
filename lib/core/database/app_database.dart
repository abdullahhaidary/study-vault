import 'dart:convert';

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

  /// `notStarted` | `studying` | `reviewed` | `mastered`.
  TextColumn get progressStatus =>
      text().withDefault(const Constant('notStarted'))();
  DateTimeColumn get lastStudiedAt => dateTime().nullable()();
  DateTimeColumn get progressUpdatedAt => dateTime().nullable()();

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

/// Lightweight PDF page bookmarks (one per material page).
class MaterialBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get materialId =>
      text().references(LessonMaterials, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {materialId, pageNumber},
  ];
}

/// Rich notes owned by a subject or lesson (exactly one parent set).
class StudyNotes extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text().nullable().references(
    Subjects,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get lessonId =>
      text().nullable().references(Lessons, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// Quill Delta JSON (same codec as Study Pin Full Notes).
  TextColumn get content => text()();

  /// Plain-text extraction for local search.
  TextColumn get plainTextContent => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Flashcards — separate study objects; may link to a source Study Pin.
class Flashcards extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text().nullable().references(
    Subjects,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get lessonId =>
      text().nullable().references(Lessons, #id, onDelete: KeyAction.cascade)();

  /// At most one auto-linked flashcard per pin (SQLite allows multiple NULLs).
  TextColumn get sourceStudyPinId => text().nullable().references(
    StudyPins,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get front => text()();

  /// Quill Delta JSON for the back (rich note).
  TextColumn get back => text()();
  TextColumn get backPlainText => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceStudyPinId},
  ];
}

/// Gemini AI Chat conversations (local source of truth).
class AiChats extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get modelId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();

  /// Unsent composer draft restored when reopening the chat.
  TextColumn get draftText => text().nullable()();

  /// JSON list of draft [AiContextItem] chips (metadata; packed text optional).
  TextColumn get draftContextJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages belonging to an [AiChats] conversation.
class AiChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId =>
      text().references(AiChats, #id, onDelete: KeyAction.cascade)();

  /// `user` | `assistant` | `system`
  TextColumn get role => text()();
  TextColumn get content => text()();

  /// `ok` | `error` | null (normal).
  TextColumn get status => text().nullable()();

  /// JSON list of attached study context (includes packedText once at send).
  TextColumn get contextJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Optional provider usage metrics (assistant turns only).
  TextColumn get aiProvider => text().nullable()();
  TextColumn get aiModel => text().nullable()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  IntColumn get cacheHitTokens => integer().nullable()();
  IntColumn get cacheMissTokens => integer().nullable()();
  IntColumn get requestDurationMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Normalized index of study-item references attached to sent AI chat messages.
///
/// [contextJson] on [AiChatMessages] remains the source of truth for chips /
/// packed text; this table enables reverse lookup by study entity ID.
class AiMessageContextRefs extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(AiChatMessages, #id, onDelete: KeyAction.cascade)();
  TextColumn get chatId =>
      text().references(AiChats, #id, onDelete: KeyAction.cascade)();

  /// [AiContextKind.storageValue]: lesson | material | note | studyPin
  TextColumn get contextType => text()();
  TextColumn get contextId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {messageId, contextType, contextId},
  ];
}

/// Versioned AI generations for annotation / PDF-selection study actions.
///
/// Each regenerate creates a new row; completed [responseText] is immutable.
class AnnotationAiGenerations extends Table {
  TextColumn get id => text()();

  /// Source annotation when acting on an existing pin (SET NULL on pin delete).
  TextColumn get annotationId => text().nullable().references(
    StudyPins,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get materialId => text().nullable().references(
    LessonMaterials,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get lessonId =>
      text().nullable().references(Lessons, #id, onDelete: KeyAction.setNull)();
  IntColumn get pageNumber => integer().nullable()();

  /// Stable grouping key for selection/annotation + material scope.
  TextColumn get sourceFingerprint => text()();

  /// [AiStudyAction.name] value (explain, summarize, …).
  TextColumn get actionType => text()();

  /// Snapshot of the text sent to the model (selection / annotation body).
  TextColumn get inputText => text()();

  /// Limited surrounding context snapshot (not the full PDF).
  TextColumn get contextSnapshot => text().nullable()();

  /// Mode / custom prompt / regenerate instruction snapshot.
  TextColumn get customPrompt => text().nullable()();

  /// Optional mode name (summarize/rephrase/organize/translate target).
  TextColumn get actionMode => text().nullable()();

  /// Completed AI output (immutable after insert).
  TextColumn get responseText => text()();

  /// `text` | `flashcards` | `questions` | `annotation`
  TextColumn get responseKind => text().withDefault(const Constant('text'))();

  TextColumn get language => text().nullable()();
  TextColumn get modelName => text().nullable()();
  TextColumn get provider => text().withDefault(const Constant('gemini'))();
  TextColumn get promptVersion => text().nullable()();

  TextColumn get parentGenerationId => text().nullable()();
  IntColumn get generationNumber => integer()();

  TextColumn get linkedQuestionSetId => text().nullable()();
  TextColumn get linkedFlashcardBatchId => text().nullable()();

  /// Optional provider usage metrics for this generation.
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  IntColumn get cacheHitTokens => integer().nullable()();
  IntColumn get cacheMissTokens => integer().nullable()();
  IntColumn get requestDurationMs => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Immutable, versioned whole-PDF AI study artifacts.
class PdfAiMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get materialId =>
      text().references(LessonMaterials, #id, onDelete: KeyAction.cascade)();

  /// [PdfAiMaterialType.storageValue].
  TextColumn get type => text()();
  TextColumn get content => text()();
  IntColumn get version => integer()();
  DateTimeColumn get generatedAt => dateTime()();

  TextColumn get provider => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  IntColumn get cacheHitTokens => integer().nullable()();
  IntColumn get cacheMissTokens => integer().nullable()();
  IntColumn get requestDurationMs => integer().nullable()();

  /// SHA-256 of the deterministic extracted page representation.
  TextColumn get sourceFingerprint => text()();
  TextColumn get customInstruction => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {materialId, type, version},
  ];
}

/// AI-generated quiz sets (first-class study objects).
class QuestionSets extends Table {
  TextColumn get id => text()();
  TextColumn get materialId => text().nullable().references(
    LessonMaterials,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get lessonId =>
      text().nullable().references(Lessons, #id, onDelete: KeyAction.setNull)();
  TextColumn get subjectId => text().nullable().references(
    Subjects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// `selected_text` | `page` | `pages` | `material` | `annotations` |
  /// `notes` | `annotations_and_notes`
  TextColumn get sourceType => text()();
  TextColumn get sourceReference => text().nullable()();
  IntColumn get questionCount => integer()();

  /// Requested generation type: `mcq` | `true_false` | `short_answer` |
  /// `fill_blank` | `mixed`
  TextColumn get questionType => text()();

  /// `easy` | `medium` | `hard` | `mixed`
  TextColumn get difficulty => text()();
  TextColumn get aiProvider => text().withDefault(const Constant('gemini'))();
  TextColumn get aiModel => text().nullable()();

  /// Optional aggregated usage for the generation request(s).
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  IntColumn get cacheHitTokens => integer().nullable()();
  IntColumn get cacheMissTokens => integer().nullable()();
  IntColumn get requestDurationMs => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual questions belonging to a [QuestionSets] row.
class QuizQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get questionSetId =>
      text().references(QuestionSets, #id, onDelete: KeyAction.cascade)();

  /// `mcq` | `true_false` | `short_answer` | `fill_blank`
  TextColumn get type => text()();
  TextColumn get question => text()();

  /// Serialized correct answer (MCQ index, `true`/`false`, or text).
  TextColumn get correctAnswer => text()();
  TextColumn get explanation => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  IntColumn get sourcePage => integer().nullable()();
  TextColumn get sourceText => text().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Options for MCQ / True-False questions.
class QuizQuestionOptions extends Table {
  TextColumn get id => text()();
  TextColumn get questionId =>
      text().references(QuizQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get optionText => text()();
  BoolColumn get isCorrect => boolean()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single play-through of a question set.
class QuizAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get questionSetId =>
      text().references(QuestionSets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get score => integer().nullable()();
  IntColumn get totalQuestions => integer()();

  /// `study` | `exam` (exam reserved for follow-up).
  TextColumn get mode => text().withDefault(const Constant('study'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-question answers within a [QuizAttempts] row.
class QuizAnswers extends Table {
  TextColumn get id => text()();
  TextColumn get quizAttemptId =>
      text().references(QuizAttempts, #id, onDelete: KeyAction.cascade)();
  TextColumn get questionId =>
      text().references(QuizQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get selectedOptionId => text().nullable()();
  TextColumn get answerText => text().nullable()();
  BoolColumn get isCorrect => boolean().nullable()();

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
    MaterialBookmarks,
    StudyNotes,
    Flashcards,
    AiChats,
    AiChatMessages,
    AiMessageContextRefs,
    AnnotationAiGenerations,
    PdfAiMaterials,
    QuestionSets,
    QuizQuestions,
    QuizQuestionOptions,
    QuizAttempts,
    QuizAnswers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Useful for tests — inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (Migrator m) async {
      await m.createAll();
      await seedBuiltInCategories();
      await _createAiChatIndexes();
      await _createAiMessageContextRefIndexes();
      await _createQuizIndexes();
      await _createAnnotationAiGenerationIndexes();
      await _createPdfAiMaterialIndexes();
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
      if (from < 8) {
        await m.addColumn(lessons, lessons.progressStatus);
        await m.addColumn(lessons, lessons.lastStudiedAt);
        await m.addColumn(lessons, lessons.progressUpdatedAt);
        await m.createTable(materialBookmarks);
        await m.createTable(studyNotes);
        await m.createTable(flashcards);
        await customStatement(
          "UPDATE lessons SET progress_status = 'notStarted' "
          "WHERE progress_status IS NULL OR progress_status = ''",
        );
      }
      if (from < 9) {
        await m.createTable(aiChats);
        await m.createTable(aiChatMessages);
        await _createAiChatIndexes();
      }
      if (from < 10) {
        await m.createTable(questionSets);
        await m.createTable(quizQuestions);
        await m.createTable(quizQuestionOptions);
        await m.createTable(quizAttempts);
        await m.createTable(quizAnswers);
        await _createQuizIndexes();
      }
      if (from < 11) {
        await m.createTable(annotationAiGenerations);
        await _createAnnotationAiGenerationIndexes();
      }
      if (from < 12) {
        await m.addColumn(aiChats, aiChats.draftContextJson);
        await m.addColumn(aiChatMessages, aiChatMessages.contextJson);
      }
      if (from < 13) {
        await m.addColumn(aiChatMessages, aiChatMessages.aiProvider);
        await m.addColumn(aiChatMessages, aiChatMessages.aiModel);
        await m.addColumn(aiChatMessages, aiChatMessages.promptTokens);
        await m.addColumn(aiChatMessages, aiChatMessages.completionTokens);
        await m.addColumn(aiChatMessages, aiChatMessages.totalTokens);
        await m.addColumn(aiChatMessages, aiChatMessages.cacheHitTokens);
        await m.addColumn(aiChatMessages, aiChatMessages.cacheMissTokens);
        await m.addColumn(aiChatMessages, aiChatMessages.requestDurationMs);
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.promptTokens,
        );
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.completionTokens,
        );
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.totalTokens,
        );
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.cacheHitTokens,
        );
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.cacheMissTokens,
        );
        await m.addColumn(
          annotationAiGenerations,
          annotationAiGenerations.requestDurationMs,
        );
      }
      if (from < 14) {
        await m.addColumn(questionSets, questionSets.promptTokens);
        await m.addColumn(questionSets, questionSets.completionTokens);
        await m.addColumn(questionSets, questionSets.totalTokens);
        await m.addColumn(questionSets, questionSets.cacheHitTokens);
        await m.addColumn(questionSets, questionSets.cacheMissTokens);
        await m.addColumn(questionSets, questionSets.requestDurationMs);
      }
      if (from < 15) {
        await m.createTable(aiMessageContextRefs);
        await _createAiMessageContextRefIndexes();
        await backfillAiMessageContextRefs();
      }
      if (from < 16) {
        await m.createTable(pdfAiMaterials);
        await _createPdfAiMaterialIndexes();
      }
    },
  );

  Future<void> _createPdfAiMaterialIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pdf_ai_material_source '
      'ON pdf_ai_materials (material_id, type, version DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pdf_ai_material_fingerprint '
      'ON pdf_ai_materials (source_fingerprint)',
    );
  }

  Future<void> _createAnnotationAiGenerationIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_gen_fingerprint_action '
      'ON annotation_ai_generations (source_fingerprint, action_type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_gen_annotation_action '
      'ON annotation_ai_generations (annotation_id, action_type)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_gen_scope_number '
      'ON annotation_ai_generations '
      '(source_fingerprint, action_type, generation_number)',
    );
  }

  Future<void> _createQuizIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_question_sets_lesson_id '
      'ON question_sets (lesson_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_question_sets_material_id '
      'ON question_sets (material_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quiz_questions_set_id '
      'ON quiz_questions (question_set_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_set_id '
      'ON quiz_attempts (question_set_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt_id '
      'ON quiz_answers (quiz_attempt_id)',
    );
  }

  Future<void> _createAiChatIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_chats_last_message_at '
      'ON ai_chats (last_message_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_chat_id '
      'ON ai_chat_messages (chat_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_created_at '
      'ON ai_chat_messages (created_at)',
    );
  }

  Future<void> _createAiMessageContextRefIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_msg_ctx_refs_type_id '
      'ON ai_message_context_refs (context_type, context_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_msg_ctx_refs_message_id '
      'ON ai_message_context_refs (message_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_msg_ctx_refs_chat_id '
      'ON ai_message_context_refs (chat_id)',
    );
  }

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
    await (delete(
      materialBookmarks,
    )..where((t) => t.materialId.equals(id))).go();
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

  Future<List<StudyPin>> getStudyPinsForResource(String resourceId) {
    return (select(studyPins)
          ..where((t) => t.resourceId.equals(resourceId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.pageNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
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
    // Keep source-derived flashcards when a pin is removed. SQLite foreign
    // keys are not enabled by every test/runtime executor, so apply SET NULL
    // explicitly as well as declaring it in the schema.
    await (update(flashcards)..where((t) => t.sourceStudyPinId.equals(id)))
        .write(const FlashcardsCompanion(sourceStudyPinId: Value(null)));
    // Detach AI generation history from the pin; snapshots remain.
    await (update(
      annotationAiGenerations,
    )..where((t) => t.annotationId.equals(id))).write(
      const AnnotationAiGenerationsCompanion(annotationId: Value(null)),
    );
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

  // ── Lesson Progress ──────────────────────────────────────

  Future<void> updateLessonProgress({
    required String lessonId,
    required String progressStatus,
    DateTime? lastStudiedAt,
    bool touchLastStudied = false,
  }) async {
    final now = DateTime.now();
    await (update(lessons)..where((t) => t.id.equals(lessonId))).write(
      LessonsCompanion(
        progressStatus: Value(progressStatus),
        progressUpdatedAt: Value(now),
        lastStudiedAt: touchLastStudied
            ? Value(lastStudiedAt ?? now)
            : lastStudiedAt != null
            ? Value(lastStudiedAt)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  /// Records meaningful study activity without forcing Reviewed/Mastered.
  Future<void> recordLessonStudyActivity(String lessonId) async {
    final lesson = await getLessonById(lessonId);
    if (lesson == null) return;
    final now = DateTime.now();
    final last = lesson.lastStudiedAt;
    // Throttle DB writes: skip if already recorded within the last minute.
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    final nextStatus = lesson.progressStatus == 'notStarted'
        ? 'studying'
        : lesson.progressStatus;
    await (update(lessons)..where((t) => t.id.equals(lessonId))).write(
      LessonsCompanion(
        progressStatus: Value(nextStatus),
        lastStudiedAt: Value(now),
        progressUpdatedAt: lesson.progressStatus == 'notStarted'
            ? Value(now)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Stream<List<Lesson>> watchStudyingLessons({int limit = 20}) {
    return (select(lessons)
          ..where((t) => t.progressStatus.equals('studying'))
          ..orderBy([
            (t) => OrderingTerm.desc(t.lastStudiedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ])
          ..limit(limit))
        .watch();
  }

  // ── Material Bookmarks ───────────────────────────────────

  Stream<List<MaterialBookmark>> watchBookmarksForMaterial(String materialId) {
    return (select(materialBookmarks)
          ..where((t) => t.materialId.equals(materialId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .watch();
  }

  Future<List<MaterialBookmark>> getBookmarksForMaterial(String materialId) {
    return (select(materialBookmarks)
          ..where((t) => t.materialId.equals(materialId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .get();
  }

  Future<MaterialBookmark?> getBookmarkForPage(
    String materialId,
    int pageNumber,
  ) {
    return (select(materialBookmarks)..where(
          (t) =>
              t.materialId.equals(materialId) & t.pageNumber.equals(pageNumber),
        ))
        .getSingleOrNull();
  }

  Future<int> countBookmarksForMaterial(String materialId) async {
    final count = countAll();
    final query = selectOnly(materialBookmarks)
      ..addColumns([count])
      ..where(materialBookmarks.materialId.equals(materialId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countBookmarksForLesson(String lessonId) async {
    final materialIds = await materialIdsForLesson(lessonId);
    if (materialIds.isEmpty) return 0;
    final count = countAll();
    final query = selectOnly(materialBookmarks)
      ..addColumns([count])
      ..where(materialBookmarks.materialId.isIn(materialIds));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> insertMaterialBookmark(MaterialBookmarksCompanion entry) {
    return into(materialBookmarks).insert(entry);
  }

  Future<void> updateMaterialBookmark(MaterialBookmark bookmark) {
    return update(materialBookmarks).replace(bookmark);
  }

  Future<void> deleteMaterialBookmark(String id) {
    return (delete(materialBookmarks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteBookmarkForPage(String materialId, int pageNumber) {
    return (delete(materialBookmarks)..where(
          (t) =>
              t.materialId.equals(materialId) & t.pageNumber.equals(pageNumber),
        ))
        .go();
  }

  // ── Study Notes ──────────────────────────────────────────

  Stream<List<StudyNote>> watchNotesForSubject(String subjectId) {
    return (select(studyNotes)
          ..where((t) => t.subjectId.equals(subjectId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  Stream<List<StudyNote>> watchNotesForLesson(String lessonId) {
    return (select(studyNotes)
          ..where((t) => t.lessonId.equals(lessonId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  Future<List<StudyNote>> getStudyNotesForLesson(String lessonId) {
    return (select(studyNotes)
          ..where((t) => t.lessonId.equals(lessonId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  Future<StudyNote?> getStudyNoteById(String id) {
    return (select(
      studyNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<StudyNote?> watchStudyNoteById(String id) {
    return (select(
      studyNotes,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> nextNoteSortOrder({String? subjectId, String? lessonId}) async {
    final maxExpr = studyNotes.sortOrder.max();
    final query = selectOnly(studyNotes)..addColumns([maxExpr]);
    if (subjectId != null) {
      query.where(studyNotes.subjectId.equals(subjectId));
    } else if (lessonId != null) {
      query.where(studyNotes.lessonId.equals(lessonId));
    }
    final row = await query.getSingle();
    return (row.read(maxExpr) ?? -1) + 1;
  }

  Future<void> insertStudyNote(StudyNotesCompanion entry) {
    return into(studyNotes).insert(entry);
  }

  Future<void> updateStudyNote(StudyNote note) {
    return update(studyNotes).replace(note);
  }

  Future<void> deleteStudyNote(String id) async {
    await deleteFavoritesForEntities(FavoriteEntityType.note, [id]);
    await (delete(studyNotes)..where((t) => t.id.equals(id))).go();
  }

  // ── Flashcards ───────────────────────────────────────────

  Stream<List<Flashcard>> watchFlashcardsForLesson(String lessonId) {
    return (select(flashcards)
          ..where((t) => t.lessonId.equals(lessonId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Stream<List<Flashcard>> watchFlashcardsForSubject(String subjectId) {
    return (select(flashcards)
          ..where((t) => t.subjectId.equals(subjectId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Stream<List<Flashcard>> watchAllFlashcards() {
    return (select(flashcards)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<Flashcard?> getFlashcardById(String id) {
    return (select(
      flashcards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Flashcard?> watchFlashcardById(String id) {
    return (select(
      flashcards,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<Flashcard?> getFlashcardBySourcePinId(String pinId) {
    return (select(flashcards)..where(
          (t) => t.sourceStudyPinId.equals(pinId) & t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Stream<Flashcard?> watchFlashcardBySourcePinId(String pinId) {
    return (select(flashcards)..where(
          (t) => t.sourceStudyPinId.equals(pinId) & t.deletedAt.isNull(),
        ))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<int> countFlashcardsForLesson(String lessonId) async {
    final count = countAll();
    final query = selectOnly(flashcards)
      ..addColumns([count])
      ..where(
        flashcards.lessonId.equals(lessonId) & flashcards.deletedAt.isNull(),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> insertFlashcard(FlashcardsCompanion entry) {
    return into(flashcards).insert(entry);
  }

  Future<void> updateFlashcard(Flashcard card) {
    return update(flashcards).replace(card);
  }

  Future<void> deleteFlashcard(String id) async {
    await deleteFavoritesForEntities(FavoriteEntityType.flashcard, [id]);
    await (delete(flashcards)..where((t) => t.id.equals(id))).go();
  }

  // ── AI Chat ──────────────────────────────────────────────

  Stream<List<AiChat>> watchAiChats() {
    return (select(aiChats)..orderBy([
          (t) => OrderingTerm.desc(t.lastMessageAt),
          (t) => OrderingTerm.desc(t.updatedAt),
        ]))
        .watch();
  }

  Future<List<AiChat>> getAiChats() {
    return (select(aiChats)..orderBy([
          (t) => OrderingTerm.desc(t.lastMessageAt),
          (t) => OrderingTerm.desc(t.updatedAt),
        ]))
        .get();
  }

  Future<AiChat?> getAiChatById(String id) {
    return (select(aiChats)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<AiChat?> watchAiChatById(String id) {
    return (select(aiChats)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> insertAiChat(AiChatsCompanion entry) {
    return into(aiChats).insert(entry);
  }

  Future<void> updateAiChat(AiChat chat) {
    return update(aiChats).replace(chat);
  }

  Future<void> deleteAiChat(String id) async {
    await (delete(aiChatMessages)..where((t) => t.chatId.equals(id))).go();
    await (delete(aiChats)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllAiChats() async {
    await delete(aiChatMessages).go();
    await delete(aiChats).go();
  }

  Stream<List<AiChatMessage>> watchAiChatMessages(String chatId) {
    return (select(aiChatMessages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<AiChatMessage>> getAiChatMessages(String chatId) {
    return (select(aiChatMessages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<AiChatMessage?> getLastAiChatMessage(String chatId) {
    return (select(aiChatMessages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> insertAiChatMessage(AiChatMessagesCompanion entry) async {
    await into(aiChatMessages).insert(entry);
    final messageId = entry.id.value;
    final chatId = entry.chatId.value;
    final role = entry.role.value;
    final contextJson = entry.contextJson.present
        ? entry.contextJson.value
        : null;
    final createdAt = entry.createdAt.value;
    if (role == 'user' &&
        contextJson != null &&
        contextJson.trim().isNotEmpty) {
      await replaceAiMessageContextRefs(
        messageId: messageId,
        chatId: chatId,
        contextJson: contextJson,
        createdAt: createdAt,
      );
    }
  }

  Future<void> updateAiChatMessage(AiChatMessage message) {
    return update(aiChatMessages).replace(message);
  }

  Future<void> deleteAiChatMessage(String id) async {
    // Context refs cascade via FK.
    await (delete(aiChatMessages)..where((t) => t.id.equals(id))).go();
  }

  /// Replaces indexed context refs for a sent user message from [contextJson].
  ///
  /// Malformed JSON is ignored (no throw). Duplicate kind+id pairs collapse.
  Future<void> replaceAiMessageContextRefs({
    required String messageId,
    required String chatId,
    required String? contextJson,
    required DateTime createdAt,
  }) async {
    await (delete(
      aiMessageContextRefs,
    )..where((t) => t.messageId.equals(messageId))).go();

    final pairs = _parseContextRefPairs(contextJson);
    if (pairs.isEmpty) return;

    await batch((b) {
      for (final pair in pairs) {
        b.insert(
          aiMessageContextRefs,
          AiMessageContextRefsCompanion.insert(
            id: '${messageId}_${pair.$1}_${pair.$2}',
            messageId: messageId,
            chatId: chatId,
            contextType: pair.$1,
            contextId: pair.$2,
            createdAt: createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Indexes historical [AiChatMessages.contextJson] into [aiMessageContextRefs].
  Future<void> backfillAiMessageContextRefs() async {
    final messages = await (select(
      aiChatMessages,
    )..where((t) => t.role.equals('user') & t.contextJson.isNotNull())).get();
    for (final message in messages) {
      try {
        await replaceAiMessageContextRefs(
          messageId: message.id,
          chatId: message.chatId,
          contextJson: message.contextJson,
          createdAt: message.createdAt,
        );
      } on Object {
        // Skip malformed historical rows.
      }
    }
  }

  Stream<int> watchAiMessageContextRefCount({
    required String contextType,
    required String contextId,
  }) {
    final countExp = aiMessageContextRefs.id.count();
    final query = selectOnly(aiMessageContextRefs)
      ..addColumns([countExp])
      ..where(
        aiMessageContextRefs.contextType.equals(contextType) &
            aiMessageContextRefs.contextId.equals(contextId),
      );
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return rows.first.read(countExp) ?? 0;
    });
  }

  Future<int> countAiMessageContextRefs({
    required String contextType,
    required String contextId,
  }) async {
    final countExp = aiMessageContextRefs.id.count();
    final query = selectOnly(aiMessageContextRefs)
      ..addColumns([countExp])
      ..where(
        aiMessageContextRefs.contextType.equals(contextType) &
            aiMessageContextRefs.contextId.equals(contextId),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Returns user messages that referenced [contextType]/[contextId], newest chat first.
  Future<List<AiChatMessage>> getAiMessagesReferencing({
    required String contextType,
    required String contextId,
  }) async {
    final query =
        select(aiChatMessages).join([
            innerJoin(
              aiMessageContextRefs,
              aiMessageContextRefs.messageId.equalsExp(aiChatMessages.id),
            ),
            innerJoin(aiChats, aiChats.id.equalsExp(aiChatMessages.chatId)),
          ])
          ..where(
            aiMessageContextRefs.contextType.equals(contextType) &
                aiMessageContextRefs.contextId.equals(contextId) &
                aiChatMessages.role.equals('user'),
          )
          ..orderBy([
            OrderingTerm.desc(aiChats.lastMessageAt),
            OrderingTerm.desc(aiChats.updatedAt),
            OrderingTerm.asc(aiChatMessages.createdAt),
          ]);

    final rows = await query.get();
    // Deduplicate if a message somehow has duplicate ref rows.
    final seen = <String>{};
    final result = <AiChatMessage>[];
    for (final row in rows) {
      final message = row.readTable(aiChatMessages);
      if (seen.add(message.id)) result.add(message);
    }
    return result;
  }

  Stream<List<AiChatMessage>> watchAiMessagesReferencing({
    required String contextType,
    required String contextId,
  }) {
    final query =
        select(aiChatMessages).join([
            innerJoin(
              aiMessageContextRefs,
              aiMessageContextRefs.messageId.equalsExp(aiChatMessages.id),
            ),
            innerJoin(aiChats, aiChats.id.equalsExp(aiChatMessages.chatId)),
          ])
          ..where(
            aiMessageContextRefs.contextType.equals(contextType) &
                aiMessageContextRefs.contextId.equals(contextId) &
                aiChatMessages.role.equals('user'),
          )
          ..orderBy([
            OrderingTerm.desc(aiChats.lastMessageAt),
            OrderingTerm.desc(aiChats.updatedAt),
            OrderingTerm.asc(aiChatMessages.createdAt),
          ]);

    return query.watch().map((rows) {
      final seen = <String>{};
      final result = <AiChatMessage>[];
      for (final row in rows) {
        final message = row.readTable(aiChatMessages);
        if (seen.add(message.id)) result.add(message);
      }
      return result;
    });
  }

  static List<(String, String)> _parseContextRefPairs(String? contextJson) {
    if (contextJson == null || contextJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(contextJson);
      if (decoded is! List) return const [];
      final seen = <String>{};
      final pairs = <(String, String)>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final kind = (item['kind'] as String?)?.trim();
        final id = (item['id'] as String?)?.trim();
        if (kind == null || kind.isEmpty || id == null || id.isEmpty) continue;
        final key = '$kind|$id';
        if (!seen.add(key)) continue;
        pairs.add((kind, id));
      }
      return pairs;
    } on Object {
      return const [];
    }
  }

  // ── AI Questions / Quiz ──────────────────────────────────

  Stream<List<QuestionSet>> watchQuestionSetsForLesson(String lessonId) {
    return (select(questionSets)
          ..where((t) => t.lessonId.equals(lessonId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<QuestionSet>> watchQuestionSetsForMaterial(String materialId) {
    return (select(questionSets)
          ..where((t) => t.materialId.equals(materialId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<QuestionSet?> getQuestionSetById(String id) {
    return (select(
      questionSets,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<QuestionSet?> watchQuestionSetById(String id) {
    return (select(
      questionSets,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<List<QuizQuestion>> getQuizQuestionsForSet(String questionSetId) {
    return (select(quizQuestions)
          ..where((t) => t.questionSetId.equals(questionSetId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<List<QuizQuestionOption>> getOptionsForQuestion(String questionId) {
    return (select(quizQuestionOptions)
          ..where((t) => t.questionId.equals(questionId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<List<QuizQuestionOption>> getOptionsForQuestions(
    List<String> questionIds,
  ) {
    if (questionIds.isEmpty) return Future.value(const []);
    return (select(quizQuestionOptions)
          ..where((t) => t.questionId.isIn(questionIds))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<void> insertQuestionSet(QuestionSetsCompanion entry) {
    return into(questionSets).insert(entry);
  }

  Future<void> updateQuestionSetTitle(String id, String title) async {
    final updated = await (update(questionSets)..where((t) => t.id.equals(id)))
        .write(
          QuestionSetsCompanion(
            title: Value(title.trim()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (updated != 1) throw StateError('Question set not found');
  }

  Future<void> insertQuizQuestion(QuizQuestionsCompanion entry) {
    return into(quizQuestions).insert(entry);
  }

  Future<void> insertQuizQuestionOption(QuizQuestionOptionsCompanion entry) {
    return into(quizQuestionOptions).insert(entry);
  }

  Future<void> editQuizQuestion({
    required QuizQuestion original,
    required String question,
    required String explanation,
    required String answer,
    required List<String> optionTexts,
    String? correctOptionId,
  }) async {
    if (question.trim().isEmpty || answer.trim().isEmpty) {
      throw ArgumentError('Question and answer must not be empty');
    }
    await transaction(() async {
      final options = await getOptionsForQuestion(original.id);
      if (options.length != optionTexts.length ||
          (options.isNotEmpty &&
              !options.any((option) => option.id == correctOptionId)) ||
          optionTexts.any((text) => text.trim().isEmpty)) {
        throw ArgumentError('Invalid answer options');
      }
      await update(quizQuestions).replace(
        original.copyWith(
          question: question.trim(),
          explanation: Value(
            explanation.trim().isEmpty ? null : explanation.trim(),
          ),
          correctAnswer: answer.trim(),
          updatedAt: DateTime.now(),
        ),
      );
      for (var i = 0; i < options.length; i++) {
        await update(quizQuestionOptions).replace(
          options[i].copyWith(
            optionText: optionTexts[i].trim(),
            isCorrect: options[i].id == correctOptionId,
          ),
        );
      }
    });
  }

  Future<void> insertQuizAttempt(QuizAttemptsCompanion entry) {
    return into(quizAttempts).insert(entry);
  }

  Future<void> updateQuizAttempt(QuizAttempt attempt) {
    return update(quizAttempts).replace(attempt);
  }

  Future<QuizAttempt?> getQuizAttemptById(String id) {
    return (select(
      quizAttempts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<QuizAttempt>> getQuizAttemptsForSet(String questionSetId) {
    return (select(quizAttempts)
          ..where((t) => t.questionSetId.equals(questionSetId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<void> insertQuizAnswer(QuizAnswersCompanion entry) {
    return into(quizAnswers).insert(entry);
  }

  Future<void> saveQuizAnswer({
    required String id,
    required String quizAttemptId,
    required String questionId,
    String? selectedOptionId,
    String? answerText,
    required bool isCorrect,
  }) async {
    final existing =
        await (select(quizAnswers)..where(
              (t) =>
                  t.quizAttemptId.equals(quizAttemptId) &
                  t.questionId.equals(questionId),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await into(quizAnswers).insert(
        QuizAnswersCompanion.insert(
          id: id,
          quizAttemptId: quizAttemptId,
          questionId: questionId,
          selectedOptionId: Value(selectedOptionId),
          answerText: Value(answerText),
          isCorrect: Value(isCorrect),
        ),
      );
    } else {
      await update(quizAnswers).replace(
        existing.copyWith(
          selectedOptionId: Value(selectedOptionId),
          answerText: Value(answerText),
          isCorrect: Value(isCorrect),
        ),
      );
    }
  }

  Future<List<QuizAnswer>> getQuizAnswersForAttempt(String attemptId) {
    return (select(
      quizAnswers,
    )..where((t) => t.quizAttemptId.equals(attemptId))).get();
  }

  /// Incorrect answers across attempts — extension point for future spaced review.
  Future<List<QuizAnswer>> getIncorrectQuizAnswersForSet(
    String questionSetId,
  ) async {
    final attempts = await getQuizAttemptsForSet(questionSetId);
    if (attempts.isEmpty) return const [];
    final attemptIds = [for (final a in attempts) a.id];
    return (select(quizAnswers)..where(
          (t) => t.quizAttemptId.isIn(attemptIds) & t.isCorrect.equals(false),
        ))
        .get();
  }

  Future<void> deleteQuestionSet(String id) async {
    final questions = await getQuizQuestionsForSet(id);
    final questionIds = [for (final q in questions) q.id];
    if (questionIds.isNotEmpty) {
      await (delete(
        quizQuestionOptions,
      )..where((t) => t.questionId.isIn(questionIds))).go();
    }
    final attempts = await getQuizAttemptsForSet(id);
    final attemptIds = [for (final a in attempts) a.id];
    if (attemptIds.isNotEmpty) {
      await (delete(
        quizAnswers,
      )..where((t) => t.quizAttemptId.isIn(attemptIds))).go();
      await (delete(
        quizAttempts,
      )..where((t) => t.questionSetId.equals(id))).go();
    }
    await (delete(
      quizQuestions,
    )..where((t) => t.questionSetId.equals(id))).go();
    await (delete(questionSets)..where((t) => t.id.equals(id))).go();
  }

  /// Atomically persist a fully validated generated quiz. Rolls back on error.
  Future<QuestionSet> persistGeneratedQuiz({
    required QuestionSetsCompanion setEntry,
    required List<QuizQuestionsCompanion> questions,
    required List<QuizQuestionOptionsCompanion> options,
  }) async {
    return transaction(() async {
      await into(questionSets).insert(setEntry);
      for (final q in questions) {
        await into(quizQuestions).insert(q);
      }
      for (final o in options) {
        await into(quizQuestionOptions).insert(o);
      }
      return (await getQuestionSetById(setEntry.id.value))!;
    });
  }

  // ── Annotation AI generation history ─────────────────────

  Future<List<AnnotationAiGeneration>> listAiGenerations({
    required String sourceFingerprint,
    required String actionType,
  }) {
    return (select(annotationAiGenerations)
          ..where(
            (t) =>
                t.sourceFingerprint.equals(sourceFingerprint) &
                t.actionType.equals(actionType),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.generationNumber)]))
        .get();
  }

  Future<List<AnnotationAiGeneration>> listAiGenerationsForAnnotation(
    String annotationId,
  ) {
    return (select(annotationAiGenerations)
          ..where((t) => t.annotationId.equals(annotationId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.actionType),
            (t) => OrderingTerm.asc(t.generationNumber),
          ]))
        .get();
  }

  Future<AnnotationAiGeneration?> getAiGenerationById(String id) {
    return (select(
      annotationAiGenerations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Counts per action for a source fingerprint (no response bodies).
  Future<Map<String, int>> countAiGenerationsByAction(
    String sourceFingerprint,
  ) async {
    final rows = await customSelect(
      'SELECT action_type AS action_type, COUNT(*) AS c '
      'FROM annotation_ai_generations '
      'WHERE source_fingerprint = ? '
      'GROUP BY action_type',
      variables: [Variable.withString(sourceFingerprint)],
      readsFrom: {annotationAiGenerations},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('action_type'): row.read<int>('c'),
    };
  }

  Future<int> nextAiGenerationNumber({
    required String sourceFingerprint,
    required String actionType,
  }) async {
    final row = await customSelect(
      'SELECT COALESCE(MAX(generation_number), 0) AS m '
      'FROM annotation_ai_generations '
      'WHERE source_fingerprint = ? AND action_type = ?',
      variables: [
        Variable.withString(sourceFingerprint),
        Variable.withString(actionType),
      ],
      readsFrom: {annotationAiGenerations},
    ).getSingle();
    return row.read<int>('m') + 1;
  }

  /// Inserts a generation with a monotonic [generationNumber] in a transaction.
  Future<AnnotationAiGeneration> insertAiGeneration({
    required String sourceFingerprint,
    required String actionType,
    required AnnotationAiGenerationsCompanion Function(int generationNumber)
    builder,
  }) {
    return transaction(() async {
      final next = await nextAiGenerationNumber(
        sourceFingerprint: sourceFingerprint,
        actionType: actionType,
      );
      final entry = builder(next);
      await into(annotationAiGenerations).insert(entry);
      return (await getAiGenerationById(entry.id.value))!;
    });
  }

  Future<AnnotationAiGeneration> editAiGeneration({
    required AnnotationAiGeneration original,
    required String id,
    required String responseText,
  }) {
    if (responseText.trim().isEmpty) {
      throw ArgumentError.value(responseText, 'responseText');
    }
    final now = DateTime.now();
    return insertAiGeneration(
      sourceFingerprint: original.sourceFingerprint,
      actionType: original.actionType,
      builder: (generationNumber) => AnnotationAiGenerationsCompanion.insert(
        id: id,
        annotationId: Value(original.annotationId),
        materialId: Value(original.materialId),
        lessonId: Value(original.lessonId),
        pageNumber: Value(original.pageNumber),
        sourceFingerprint: original.sourceFingerprint,
        actionType: original.actionType,
        inputText: original.inputText,
        contextSnapshot: Value(original.contextSnapshot),
        customPrompt: Value(original.customPrompt),
        actionMode: Value(original.actionMode),
        responseText: responseText.trim(),
        responseKind: Value(original.responseKind),
        language: Value(original.language),
        provider: Value(original.provider),
        promptVersion: Value(original.promptVersion),
        parentGenerationId: Value(original.id),
        generationNumber: generationNumber,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> deleteAiGeneration(String id) async {
    await (delete(annotationAiGenerations)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteAiGenerationsForAction({
    required String sourceFingerprint,
    required String actionType,
  }) {
    return (delete(annotationAiGenerations)..where(
          (t) =>
              t.sourceFingerprint.equals(sourceFingerprint) &
              t.actionType.equals(actionType),
        ))
        .go();
  }

  // ── Whole-PDF AI study materials ─────────────────────────

  Stream<List<PdfAiMaterial>> watchPdfAiMaterials(String materialId) {
    return (select(pdfAiMaterials)
          ..where((t) => t.materialId.equals(materialId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.type),
            (t) => OrderingTerm.desc(t.version),
          ]))
        .watch();
  }

  Future<List<PdfAiMaterial>> listPdfAiMaterials({
    required String materialId,
    required String type,
  }) {
    return (select(pdfAiMaterials)
          ..where((t) => t.materialId.equals(materialId) & t.type.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.version)]))
        .get();
  }

  Future<PdfAiMaterial?> getPdfAiMaterialById(String id) {
    return (select(
      pdfAiMaterials,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> nextPdfAiMaterialVersion({
    required String materialId,
    required String type,
  }) async {
    final maxVersion = pdfAiMaterials.version.max();
    final query = selectOnly(pdfAiMaterials)
      ..addColumns([maxVersion])
      ..where(
        pdfAiMaterials.materialId.equals(materialId) &
            pdfAiMaterials.type.equals(type),
      );
    final row = await query.getSingle();
    return (row.read(maxVersion) ?? 0) + 1;
  }

  Future<PdfAiMaterial> insertPdfAiMaterialVersion({
    required String materialId,
    required String type,
    required PdfAiMaterialsCompanion Function(int version) builder,
  }) {
    return transaction(() async {
      final version = await nextPdfAiMaterialVersion(
        materialId: materialId,
        type: type,
      );
      final entry = builder(version);
      await into(pdfAiMaterials).insert(entry);
      return (await getPdfAiMaterialById(entry.id.value))!;
    });
  }

  Future<PdfAiMaterial> editPdfAiMaterial({
    required PdfAiMaterial original,
    required String id,
    required String content,
  }) {
    if (content.trim().isEmpty) throw ArgumentError.value(content, 'content');
    return insertPdfAiMaterialVersion(
      materialId: original.materialId,
      type: original.type,
      builder: (version) => PdfAiMaterialsCompanion.insert(
        id: id,
        materialId: original.materialId,
        type: original.type,
        content: content.trim(),
        version: version,
        generatedAt: DateTime.now(),
        sourceFingerprint: original.sourceFingerprint,
      ),
    );
  }

  Future<PdfAiMaterial> updatePdfAiMaterialContent({
    required String id,
    required String content,
  }) async {
    if (content.trim().isEmpty) throw ArgumentError.value(content, 'content');
    await (update(pdfAiMaterials)..where((t) => t.id.equals(id))).write(
      PdfAiMaterialsCompanion(content: Value(content.trim())),
    );
    return (await getPdfAiMaterialById(id))!;
  }

  Future<void> deletePdfAiMaterial(String id) async {
    await (delete(pdfAiMaterials)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await StudyVaultPaths.databaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
