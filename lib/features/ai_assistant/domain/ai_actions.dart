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
abstract final class AiModelIds {
  static const recommended = 'gemini-2.5-flash';
  static const flash35 = 'gemini-3.5-flash';

  static const all = [recommended, flash35];

  static String label(String id) => switch (id) {
    recommended => 'Recommended (2.5 Flash)',
    flash35 => 'Gemini 3.5 Flash',
    _ => id,
  };
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
