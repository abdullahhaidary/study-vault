import 'package:flutter/painting.dart';

import 'ai_actions.dart';
import 'ai_models.dart';

/// Normalized study context for annotation / PDF-selection AI.
///
/// Built once in the UI layer; Gemini receives [AiStudyRequest] derived from
/// this — never raw widget state.
class AnnotationAiContext {
  const AnnotationAiContext({
    required this.selectedText,
    this.materialId,
    this.lessonId,
    this.pageNumber,
    this.annotationText,
    this.surroundingText,
    this.annotationId,
    this.shortDescription,
    this.language = AiLanguage.auto,
    this.direction,
    this.filePath,
  });

  final String? materialId;
  final String? lessonId;
  final int? pageNumber;

  /// Primary selected PDF / pin text.
  final String selectedText;

  /// Optional pin short + full note when acting on an existing annotation.
  final String? annotationText;

  /// Limited surrounding page text (not the whole PDF).
  final String? surroundingText;

  final String? annotationId;
  final String? shortDescription;
  final AiLanguage language;
  final TextDirection? direction;

  /// Optional PDF path for re-extracting surrounding text later.
  final String? filePath;

  /// Best primary text for Gemini (selection, else annotation body).
  String get primaryText {
    final selected = selectedText.trim();
    if (selected.isNotEmpty) return selected;
    return (annotationText ?? '').trim();
  }

  bool get hasUsableText => primaryText.isNotEmpty;

  AiStudyRequest toStudyRequest({
    required AiStudyAction action,
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    AiQuestionType? questionType,
    int questionCount = 5,
    AiQuestionDifficulty questionDifficulty = AiQuestionDifficulty.mixed,
    int flashcardCount = 5,
    List<String> categoryNames = const [],
    String? userPreference,
    String? customPrompt,
    List<AiConversationTurn> conversation = const [],
    AiLanguage? languageOverride,
    AiLanguage? translateTarget,
    AiPageSendMode pageSendMode = AiPageSendMode.text,
    AiStudyImage? image,
  }) {
    final usingImage = pageSendMode == AiPageSendMode.image || image != null;
    final primary = primaryText;
    final source = primary.isNotEmpty
        ? primary
        : 'PDF page ${pageNumber ?? ''} (image attached)'.trim();
    return AiStudyRequest(
      action: action,
      sourceText: source,
      language: languageOverride ?? language,
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      questionType: questionType,
      questionCount: questionCount,
      questionDifficulty: questionDifficulty,
      flashcardCount: flashcardCount,
      categoryNames: categoryNames,
      userPreference: userPreference,
      selectedText: selectedText.trim().isEmpty ? null : selectedText.trim(),
      shortDescription: shortDescription,
      surroundingText: usingImage ? null : surroundingText,
      pageNumber: pageNumber,
      materialId: materialId,
      lessonId: lessonId,
      annotationId: annotationId,
      customPrompt: customPrompt,
      conversation: conversation,
      translateTarget: translateTarget,
      pageSendMode: usingImage ? AiPageSendMode.image : AiPageSendMode.text,
      image: image,
    );
  }
}
