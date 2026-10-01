import 'ai_actions.dart';

/// Soft size limit before warning the user (characters).
const kAiSoftSourceLimit = 12000;

/// Hard reject above this (characters).
const kAiHardSourceLimit = 40000;

class AiStudyRequest {
  const AiStudyRequest({
    required this.action,
    required this.sourceText,
    this.language = AiLanguage.auto,
    this.rephraseMode,
    this.organizeMode,
    this.summarizeMode,
    this.questionType,
    this.flashcardCount = 3,
    this.categoryNames = const [],
    this.userPreference,
    this.selectedText,
    this.shortDescription,
  });

  final AiStudyAction action;
  final String sourceText;
  final AiLanguage language;
  final AiRephraseMode? rephraseMode;
  final AiOrganizeMode? organizeMode;
  final AiSummarizeMode? summarizeMode;
  final AiQuestionType? questionType;
  final int flashcardCount;
  final List<String> categoryNames;
  final String? userPreference;
  final String? selectedText;
  final String? shortDescription;
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

class AiQuestionDraft {
  const AiQuestionDraft({
    required this.question,
    required this.answer,
    this.choices,
    this.correctIndex,
    this.explanation,
  });

  final String question;
  final String answer;
  final List<String>? choices;
  final int? correctIndex;
  final String? explanation;
}

class AiQuestionsResult extends AiStudyResult {
  const AiQuestionsResult({required this.questions});
  final List<AiQuestionDraft> questions;
}
