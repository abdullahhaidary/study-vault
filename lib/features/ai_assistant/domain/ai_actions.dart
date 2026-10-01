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

enum AiLanguage {
  auto,
  english,
  persianDari,
}

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

enum AiQuestionType {
  conceptual,
  shortAnswer,
  mixed,
}

/// Centralized Gemini model IDs — do not scatter elsewhere.
///
/// Keep in sync with https://ai.google.dev/gemini-api/docs/models
abstract final class AiModelIds {
  /// Current recommended Flash model for study actions.
  static const recommended = 'gemini-3.8-flash';

  /// Previous-generation Flash (broad availability fallback).
  static const flash25 = 'gemini-2.5-flash';

  /// Cheaper / faster lite variant.
  static const flashLite = 'gemini-2.5-flash-lite';

  static const all = [recommended, flash25, flashLite];

  static String label(String id) => switch (id) {
    recommended => 'Recommended (Gemini 3.8 Flash)',
    flash25 => 'Gemini 2.5 Flash',
    flashLite => 'Gemini 2.5 Flash-Lite',
    _ => id,
  };

  /// Falls back when a stored preference is obsolete / unavailable.
  static String normalize(String? id) {
    // Migrate older stored preferences to the current recommended model.
    if (id == 'gemini-3.5-flash') return recommended;
    if (id != null && all.contains(id)) return id;
    return recommended;
  }
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
    AiStudyAction.fixGrammar => 'Fix Grammar',
    AiStudyAction.organize => 'Organize',
    AiStudyAction.summarize => 'Summarize',
    AiStudyAction.createAnnotation => 'Create Annotation',
    AiStudyAction.generateFlashcards => 'Generate Flashcards',
    AiStudyAction.generateQuestions => 'Generate Questions',
  };
}

extension AiLanguageX on AiLanguage {
  String get label => switch (this) {
    AiLanguage.auto => 'Auto',
    AiLanguage.english => 'English',
    AiLanguage.persianDari => 'Persian/Dari',
  };

  String get storageValue => name;

  static AiLanguage fromStorage(String? value) {
    return AiLanguage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiLanguage.auto,
    );
  }
}
