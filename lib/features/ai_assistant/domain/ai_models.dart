import 'dart:typed_data';

import '../../ai_questions/domain/quiz_models.dart';
import 'ai_actions.dart';
import 'ai_execution_selection.dart';
import 'ai_token_usage.dart';

/// Soft size limit before warning the user (characters).
const kAiSoftSourceLimit = 12000;

/// Hard reject above this (characters) for a single Gemini call.
const kAiHardSourceLimit = 40000;

/// Max surrounding context characters included with a selection.
const kAiSurroundingContextLimit = 2500;

/// Max characters of summary / full-document context sent with a selection.
const kAiDocumentContextLimit = 30000;

/// What extra material is sent alongside a text selection.
enum AiContextScope { selectionOnly, surrounding, summary, fullText }

extension AiContextScopeX on AiContextScope {
  String get label => switch (this) {
    AiContextScope.selectionOnly => 'Selection only',
    AiContextScope.surrounding => 'Selection + nearby text',
    AiContextScope.summary => 'Selection + summary',
    AiContextScope.fullText => 'Selection + full text',
  };

  String get shortLabel => switch (this) {
    AiContextScope.selectionOnly => 'Selection',
    AiContextScope.surrounding => '+ Nearby',
    AiContextScope.summary => '+ Summary',
    AiContextScope.fullText => '+ Full text',
  };

  String get description => switch (this) {
    AiContextScope.selectionOnly =>
      'Fastest and cheapest. AI sees only what you selected.',
    AiContextScope.surrounding => 'Adds the paragraphs around the selection.',
    AiContextScope.summary => 'Adds the saved summary so AI knows the topic.',
    AiContextScope.fullText =>
      'Adds the whole document (truncated if very long).',
  };

  /// Heading used in the prompt for the extra context block.
  String get promptLabel => switch (this) {
    AiContextScope.selectionOnly => 'SURROUNDING CONTEXT',
    AiContextScope.surrounding => 'SURROUNDING CONTEXT',
    AiContextScope.summary => 'DOCUMENT SUMMARY',
    AiContextScope.fullText => 'FULL DOCUMENT TEXT',
  };
}

/// Longest side (pixels) when rendering a PDF page for vision.
const kAiPageImageLongestSide = 1024.0;

/// Hard cap on encoded JPEG bytes for one page image.
const kAiMaxPageImageBytes = 400 * 1024;

/// How a single PDF page is sent to the model.
enum AiPageSendMode { text, image }

extension AiPageSendModeX on AiPageSendMode {
  String get label => switch (this) {
    AiPageSendMode.text => 'Text',
    AiPageSendMode.image => 'Image',
  };
}

/// One locally rendered PDF page (never the PDF file itself).
class AiStudyImage {
  const AiStudyImage({
    required this.bytes,
    required this.mimeType,
    this.pageNumber,
  });

  final Uint8List bytes;
  final String mimeType;
  final int? pageNumber;
}

/// One turn in a lightweight annotation-scoped follow-up chat.
class AiConversationTurn {
  const AiConversationTurn({
    required this.userMessage,
    required this.assistantMarkdown,
  });

  final String userMessage;
  final String assistantMarkdown;
}

class AiStudyRequest {
  const AiStudyRequest({
    required this.action,
    required this.sourceText,
    required this.selection,
    this.language = AiLanguage.auto,
    this.rephraseMode,
    this.organizeMode,
    this.summarizeMode,
    this.questionType,
    this.questionCount = 5,
    this.questionDifficulty = AiQuestionDifficulty.mixed,
    this.flashcardCount = 5,
    this.categoryNames = const [],
    this.userPreference,
    this.selectedText,
    this.shortDescription,
    this.surroundingText,
    this.surroundingLabel,
    this.pageNumber,
    this.materialId,
    this.lessonId,
    this.annotationId,
    this.customPrompt,
    this.conversation = const [],
    this.translateTarget,
    this.pageSendMode = AiPageSendMode.text,
    this.image,
  });

  final AiStudyAction action;
  final String sourceText;
  final AiExecutionSelection selection;
  final AiLanguage language;
  final AiRephraseMode? rephraseMode;
  final AiOrganizeMode? organizeMode;
  final AiSummarizeMode? summarizeMode;
  final AiQuestionType? questionType;
  final int questionCount;
  final AiQuestionDifficulty questionDifficulty;
  final int flashcardCount;
  final List<String> categoryNames;
  final String? userPreference;
  final String? selectedText;
  final String? shortDescription;

  /// Limited surrounding page / paragraph text for clarity.
  final String? surroundingText;

  /// Prompt heading for [surroundingText] (defaults to surrounding context).
  final String? surroundingLabel;
  final int? pageNumber;
  final String? materialId;
  final String? lessonId;
  final String? annotationId;

  /// Free-form user question (Ask AI) or custom instruction.
  final String? customPrompt;

  /// Prior turns for annotation-scoped follow-ups.
  final List<AiConversationTurn> conversation;

  /// Target language for [AiStudyAction.translate].
  final AiLanguage? translateTarget;

  final AiPageSendMode pageSendMode;
  final AiStudyImage? image;

  bool get hasPageImage => image != null;

  /// Combined character budget used for size checks (source + surrounding).
  int get effectiveSourceLength =>
      sourceText.length + (surroundingText?.length ?? 0);

  AiStudyRequest copyWith({
    AiStudyAction? action,
    String? sourceText,
    AiExecutionSelection? selection,
    AiLanguage? language,
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    AiQuestionType? questionType,
    int? questionCount,
    AiQuestionDifficulty? questionDifficulty,
    int? flashcardCount,
    List<String>? categoryNames,
    String? userPreference,
    String? selectedText,
    String? shortDescription,
    String? surroundingText,
    String? surroundingLabel,
    int? pageNumber,
    String? materialId,
    String? lessonId,
    String? annotationId,
    String? customPrompt,
    List<AiConversationTurn>? conversation,
    AiLanguage? translateTarget,
    AiPageSendMode? pageSendMode,
    AiStudyImage? image,
  }) {
    return AiStudyRequest(
      action: action ?? this.action,
      sourceText: sourceText ?? this.sourceText,
      selection: selection ?? this.selection,
      language: language ?? this.language,
      rephraseMode: rephraseMode ?? this.rephraseMode,
      organizeMode: organizeMode ?? this.organizeMode,
      summarizeMode: summarizeMode ?? this.summarizeMode,
      questionType: questionType ?? this.questionType,
      questionCount: questionCount ?? this.questionCount,
      questionDifficulty: questionDifficulty ?? this.questionDifficulty,
      flashcardCount: flashcardCount ?? this.flashcardCount,
      categoryNames: categoryNames ?? this.categoryNames,
      userPreference: userPreference ?? this.userPreference,
      selectedText: selectedText ?? this.selectedText,
      shortDescription: shortDescription ?? this.shortDescription,
      surroundingText: surroundingText ?? this.surroundingText,
      surroundingLabel: surroundingLabel ?? this.surroundingLabel,
      pageNumber: pageNumber ?? this.pageNumber,
      materialId: materialId ?? this.materialId,
      lessonId: lessonId ?? this.lessonId,
      annotationId: annotationId ?? this.annotationId,
      customPrompt: customPrompt ?? this.customPrompt,
      conversation: conversation ?? this.conversation,
      translateTarget: translateTarget ?? this.translateTarget,
      pageSendMode: pageSendMode ?? this.pageSendMode,
      image: image ?? this.image,
    );
  }
}

/// Dedicated request for first-class quiz generation.
class AiQuestionGenerationRequest {
  const AiQuestionGenerationRequest({
    required this.sourceText,
    required this.count,
    required this.type,
    required this.difficulty,
    required this.selection,
    this.language = AiLanguage.auto,
    this.userPreference,
    this.pageNumber,
    this.image,
  });

  final String sourceText;
  final int count;
  final AiQuestionType type;
  final AiQuestionDifficulty difficulty;
  final AiExecutionSelection selection;
  final AiLanguage language;
  final String? userPreference;
  final int? pageNumber;
  final AiStudyImage? image;

  AiStudyRequest toStudyRequest() {
    return AiStudyRequest(
      action: AiStudyAction.generateQuestions,
      sourceText: sourceText,
      selection: selection,
      language: language,
      questionType: type,
      questionCount: count,
      questionDifficulty: difficulty,
      userPreference: userPreference,
      pageNumber: pageNumber ?? image?.pageNumber,
      pageSendMode: image == null ? AiPageSendMode.text : AiPageSendMode.image,
      image: image,
    );
  }
}

sealed class AiStudyResult {
  const AiStudyResult({this.usage});

  /// Optional provider usage attached after the API call.
  final AiTokenUsage? usage;
}

class AiTextResult extends AiStudyResult {
  const AiTextResult({required this.markdown, super.usage});
  final String markdown;

  AiTextResult withUsage(AiTokenUsage? next) =>
      AiTextResult(markdown: markdown, usage: next);
}

class AiAnnotationDraft extends AiStudyResult {
  const AiAnnotationDraft({
    required this.shortDescription,
    required this.fullNoteMarkdown,
    this.suggestedCategory,
    super.usage,
  });

  final String shortDescription;
  final String fullNoteMarkdown;
  final String? suggestedCategory;

  AiAnnotationDraft withUsage(AiTokenUsage? next) => AiAnnotationDraft(
    shortDescription: shortDescription,
    fullNoteMarkdown: fullNoteMarkdown,
    suggestedCategory: suggestedCategory,
    usage: next,
  );
}

class AiFlashcardDraft {
  const AiFlashcardDraft({required this.front, required this.back});
  final String front;
  final String back;
}

class AiFlashcardsResult extends AiStudyResult {
  const AiFlashcardsResult({required this.cards, super.usage});
  final List<AiFlashcardDraft> cards;

  AiFlashcardsResult withUsage(AiTokenUsage? next) =>
      AiFlashcardsResult(cards: cards, usage: next);
}

/// Legacy-compatible draft used by the simple preview screen.
class AiQuestionDraft {
  const AiQuestionDraft({
    required this.question,
    required this.answer,
    this.type = QuizQuestionType.shortAnswer,
    this.choices,
    this.correctIndex,
    this.explanation,
    this.difficulty,
    this.sourcePage,
  });

  final String question;
  final String answer;
  final QuizQuestionType type;
  final List<String>? choices;
  final int? correctIndex;
  final String? explanation;
  final QuizDifficulty? difficulty;
  final int? sourcePage;
}

class AiQuestionsResult extends AiStudyResult {
  const AiQuestionsResult({
    required this.questions,
    this.title = 'Generated Quiz',
    this.generated,
    super.usage,
  });

  final String title;
  final List<AiQuestionDraft> questions;

  /// Strictly validated quiz payload used for persistence / Quiz Mode.
  final GeneratedQuiz? generated;

  AiQuestionsResult withUsage(AiTokenUsage? next) => AiQuestionsResult(
    questions: questions,
    title: title,
    generated: generated,
    usage: next,
  );
}
