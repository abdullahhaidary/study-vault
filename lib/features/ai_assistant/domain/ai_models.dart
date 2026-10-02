import 'dart:typed_data';

import '../../ai_questions/domain/quiz_models.dart';
import 'ai_actions.dart';

/// Soft size limit before warning the user (characters).
const kAiSoftSourceLimit = 12000;

/// Hard reject above this (characters) for a single Gemini call.
const kAiHardSourceLimit = 40000;

/// Max surrounding context characters included with a selection.
const kAiSurroundingContextLimit = 2500;

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
    this.language = AiLanguage.auto,
    this.userPreference,
    this.pageNumber,
    this.image,
  });

  final String sourceText;
  final int count;
  final AiQuestionType type;
  final AiQuestionDifficulty difficulty;
  final AiLanguage language;
  final String? userPreference;
  final int? pageNumber;
  final AiStudyImage? image;

  AiStudyRequest toStudyRequest() {
    return AiStudyRequest(
      action: AiStudyAction.generateQuestions,
      sourceText: sourceText,
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
  const AiStudyResult();
}

class AiTextResult extends AiStudyResult {
  const AiTextResult({required this.markdown});
  final String markdown;
}

class AiAnnotationDraft extends AiStudyResult {
  const AiAnnotationDraft({
    required this.shortDescription,
    required this.fullNoteMarkdown,
    this.suggestedCategory,
  });

  final String shortDescription;
  final String fullNoteMarkdown;
  final String? suggestedCategory;
}

class AiFlashcardDraft {
  const AiFlashcardDraft({required this.front, required this.back});
  final String front;
  final String back;
}

class AiFlashcardsResult extends AiStudyResult {
  const AiFlashcardsResult({required this.cards});
  final List<AiFlashcardDraft> cards;
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
  });

  final String title;
  final List<AiQuestionDraft> questions;

  /// Strictly validated quiz payload used for persistence / Quiz Mode.
  final GeneratedQuiz? generated;
}
