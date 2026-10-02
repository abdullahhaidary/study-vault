import 'gemini_model_registry.dart';

/// Study-focused AI actions (user-initiated only).
enum AiStudyAction {
  explain,
  simplify,
  rephrase,
  fixGrammar,
  organize,
  summarize,
  createAnnotation,
  generateFlashcards,
  generateQuestions,
}

enum AiLanguage { auto, english, persianDari }

enum AiRephraseMode {
  clearer,
  simpler,
  moreAcademic,
  shorter,
  moreConcise,
  fixGrammar,
  preserveMeaning,
}

enum AiOrganizeMode {
  cleanFormatting,
  addHeadings,
  convertToBullets,
  turnIntoStudyNotes,
  organizeAcademically,
  examReady,
}

enum AiSummarizeMode {
  veryShort,
  oneParagraph,
  bulletPoints,
  keyPoints,
  examSummary,
}

enum AiQuestionType { conceptual, shortAnswer, mixed }

/// Centralized Gemini model IDs — delegates to [GeminiModelRegistry].
abstract final class AiModelIds {
  static const recommended = GeminiModelRegistry.defaultModelId;

  /// Compatibility aliases used by older settings UI / tests.
  static const flash25 = 'gemini-2.5-flash';
  static const flashLite = 'gemini-2.5-flash-lite';

  /// Models offered in the study-action settings dropdown.
  static List<String> get all => GeminiModelRegistry.fallbackChatModels()
      .map((m) => m.id)
      .toList(growable: false);

  static String label(String id) {
    final def = GeminiModelRegistry.byId(id);
    if (def == null) return id;
    return def.recommended
        ? 'Recommended (${def.displayName})'
        : def.displayName;
  }

  /// Falls back when a stored preference is obsolete / unavailable.
  static String normalize(String? id) => GeminiModelRegistry.normalize(id);
}

extension AiStudyActionX on AiStudyAction {
  String get loadingMessage => switch (this) {
    AiStudyAction.explain => 'Generating explanation…',
    AiStudyAction.simplify => 'Simplifying…',
    AiStudyAction.rephrase => 'Rephrasing…',
    AiStudyAction.fixGrammar => 'Fixing grammar…',
    AiStudyAction.organize => 'Organizing note…',
    AiStudyAction.summarize => 'Summarizing…',
    AiStudyAction.createAnnotation => 'Drafting annotation…',
    AiStudyAction.generateFlashcards => 'Creating flashcard drafts…',
    AiStudyAction.generateQuestions => 'Generating questions…',
  };

  String get menuLabel => switch (this) {
    AiStudyAction.explain => 'Explain',
    AiStudyAction.simplify => 'Simplify',
    AiStudyAction.rephrase => 'Rephrase',
    AiStudyAction.fixGrammar => 'Fix grammar',
    AiStudyAction.organize => 'Organize',
    AiStudyAction.summarize => 'Summarize',
    AiStudyAction.createAnnotation => 'Create annotation',
    AiStudyAction.generateFlashcards => 'Generate flashcards',
    AiStudyAction.generateQuestions => 'Generate questions',
  };
}

extension AiLanguageX on AiLanguage {
  String get storageValue => name;

  String get label => switch (this) {
    AiLanguage.auto => 'Auto',
    AiLanguage.english => 'English',
    AiLanguage.persianDari => 'Persian / Dari',
  };

  static AiLanguage fromStorage(String? value) {
    return AiLanguage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiLanguage.auto,
    );
  }
}
