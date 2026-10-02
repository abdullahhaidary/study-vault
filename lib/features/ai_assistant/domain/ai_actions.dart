import 'ai_provider.dart';
import 'deepseek_model_registry.dart';
import 'gemini_model_registry.dart';

/// Study-focused AI actions (user-initiated only).
enum AiStudyAction {
  explain,
  simplify,
  rephrase,
  fixGrammar,
  organize,
  summarize,
  define,
  giveExample,
  translate,
  askAi,
  customPrompt,
  createAnnotation,
  generateFlashcards,
  generateQuestions,
  keyConcepts,
  examPoints,
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

/// Quiz question types for AI generation (aligned with quiz engine).
enum AiQuestionType { mcq, trueFalse, shortAnswer, fillBlank, mixed }

/// Quiz difficulty for AI generation.
enum AiQuestionDifficulty { easy, medium, hard, mixed }

extension AiQuestionTypeX on AiQuestionType {
  String get label => switch (this) {
    AiQuestionType.mcq => 'Multiple Choice',
    AiQuestionType.trueFalse => 'True / False',
    AiQuestionType.shortAnswer => 'Short Answer',
    AiQuestionType.fillBlank => 'Fill in the Blank',
    AiQuestionType.mixed => 'Mixed',
  };

  String get promptValue => switch (this) {
    AiQuestionType.mcq => 'mcq',
    AiQuestionType.trueFalse => 'true_false',
    AiQuestionType.shortAnswer => 'short_answer',
    AiQuestionType.fillBlank => 'fill_blank',
    AiQuestionType.mixed => 'mixed',
  };
}

extension AiQuestionDifficultyX on AiQuestionDifficulty {
  String get label => switch (this) {
    AiQuestionDifficulty.easy => 'Easy',
    AiQuestionDifficulty.medium => 'Medium',
    AiQuestionDifficulty.hard => 'Hard',
    AiQuestionDifficulty.mixed => 'Mixed',
  };

  String get promptValue => name;
}

/// Centralized Gemini model IDs — delegates to [GeminiModelRegistry].
///
/// Prefer [AiModels] when the active provider may not be Gemini.
abstract final class AiModelIds {
  static const recommended = GeminiModelRegistry.defaultModelId;

  /// Compatibility aliases used by older settings UI / tests.
  static const flash25 = 'gemini-2.5-flash';
  static const flashLite = 'gemini-2.5-flash-lite';

  /// Models offered in the study-action settings dropdown (Gemini).
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

/// Provider-aware model helpers for Settings / persistence.
abstract final class AiModels {
  static List<String> selectableIds(AiProviderId provider) =>
      switch (provider) {
        AiProviderId.gemini => AiModelIds.all,
        AiProviderId.deepseek => [
          DeepSeekModelIds.auto,
          ...DeepSeekModelRegistry.selectableModels().map((m) => m.id),
        ],
      };

  static String label(AiProviderId provider, String id) => switch (provider) {
    AiProviderId.gemini => AiModelIds.label(id),
    AiProviderId.deepseek =>
      DeepSeekModelIds.isAuto(id)
          ? 'Auto'
          : (() {
              final def = DeepSeekModelRegistry.byId(id);
              if (def == null) return id;
              return def.recommended
                  ? 'Recommended (${def.displayName})'
                  : def.displayName;
            })(),
  };

  static String normalize(AiProviderId provider, String? id) =>
      switch (provider) {
        AiProviderId.gemini => GeminiModelRegistry.normalize(id),
        AiProviderId.deepseek =>
          DeepSeekModelIds.isAuto(id)
              ? DeepSeekModelIds.auto
              : DeepSeekModelRegistry.normalize(id),
      };

  static String displayBadge({
    required String? provider,
    required String? modelName,
  }) {
    final p = AiProviderIdX.fromStorage(provider);
    final model = modelName?.trim();
    if (model == null || model.isEmpty) return p.displayName;
    final modelLabel = switch (p) {
      AiProviderId.gemini =>
        GeminiModelRegistry.byId(model)?.displayName ?? model,
      AiProviderId.deepseek =>
        DeepSeekModelRegistry.byId(model)?.displayName ?? model,
    };
    return modelLabel;
  }

  /// True if [id] is a current Gemini or DeepSeek selectable model (or Auto).
  static bool isKnown(String id) {
    if (DeepSeekModelIds.isAuto(id)) return true;
    if (DeepSeekModelRegistry.isKnown(id)) return true;
    return GeminiModelRegistry.isKnown(id);
  }

  /// Chat subtitle / app bar label. Unknown ids stay marked unavailable.
  static String chatDisplayName(String id) {
    if (DeepSeekModelIds.isAuto(id)) return 'DeepSeek Auto';
    if (DeepSeekModelRegistry.isKnown(id)) {
      return DeepSeekModelRegistry.displayName(id);
    }
    return GeminiModelRegistry.displayName(id);
  }
}

extension AiStudyActionX on AiStudyAction {
  String get loadingMessage => switch (this) {
    AiStudyAction.explain => 'Explaining selected text…',
    AiStudyAction.simplify => 'Simplifying…',
    AiStudyAction.rephrase => 'Rephrasing…',
    AiStudyAction.fixGrammar => 'Fixing grammar…',
    AiStudyAction.organize => 'Organizing note…',
    AiStudyAction.summarize => 'Summarizing…',
    AiStudyAction.define => 'Defining concept…',
    AiStudyAction.giveExample => 'Generating examples…',
    AiStudyAction.translate => 'Translating…',
    AiStudyAction.askAi => 'Asking AI…',
    AiStudyAction.customPrompt => 'Running custom prompt…',
    AiStudyAction.createAnnotation => 'Drafting annotation…',
    AiStudyAction.generateFlashcards => 'Generating flashcards…',
    AiStudyAction.generateQuestions => 'Generating questions…',
    AiStudyAction.keyConcepts => 'Extracting key concepts…',
    AiStudyAction.examPoints => 'Finding exam points…',
  };

  String get menuLabel => switch (this) {
    AiStudyAction.explain => 'Explain',
    AiStudyAction.simplify => 'Simplify',
    AiStudyAction.rephrase => 'Rephrase',
    AiStudyAction.fixGrammar => 'Fix grammar',
    AiStudyAction.organize => 'Organize',
    AiStudyAction.summarize => 'Summarize',
    AiStudyAction.define => 'Define',
    AiStudyAction.giveExample => 'Give example',
    AiStudyAction.translate => 'Translate',
    AiStudyAction.askAi => 'Ask AI',
    AiStudyAction.customPrompt => 'Custom prompt',
    AiStudyAction.createAnnotation => 'Create annotation',
    AiStudyAction.generateFlashcards => 'Create flashcards',
    AiStudyAction.generateQuestions => 'Generate questions',
    AiStudyAction.keyConcepts => 'Key concepts',
    AiStudyAction.examPoints => 'Exam points',
  };

  /// True when the result is free-form markdown (not structured JSON).
  bool get producesTextResult => switch (this) {
    AiStudyAction.explain ||
    AiStudyAction.simplify ||
    AiStudyAction.rephrase ||
    AiStudyAction.fixGrammar ||
    AiStudyAction.organize ||
    AiStudyAction.summarize ||
    AiStudyAction.define ||
    AiStudyAction.giveExample ||
    AiStudyAction.translate ||
    AiStudyAction.askAi ||
    AiStudyAction.customPrompt ||
    AiStudyAction.keyConcepts ||
    AiStudyAction.examPoints => true,
    AiStudyAction.createAnnotation ||
    AiStudyAction.generateFlashcards ||
    AiStudyAction.generateQuestions => false,
  };

  /// Safe to cache identical requests briefly (no free-form user prompt).
  bool get isCacheable => switch (this) {
    AiStudyAction.askAi ||
    AiStudyAction.customPrompt ||
    AiStudyAction.generateQuestions => false,
    _ => true,
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
