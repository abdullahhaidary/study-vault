import 'package:flutter/painting.dart';

import 'ai_actions.dart';
import 'ai_execution_selection.dart';
import 'ai_models.dart';

/// Normalized study context for annotation / PDF-selection AI.
///
/// Built once in the UI layer; the model receives [AiStudyRequest] derived from
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
    this.contextScope = AiContextScope.surrounding,
    this.sourceTitle,
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

  /// What [surroundingText] represents (nearby text, summary, full document).
  final AiContextScope contextScope;

  /// Human-readable source name (e.g. "Summary", "Note") for UI labels.
  final String? sourceTitle;

  /// Best primary text (selection, else annotation body).
  String get primaryText {
    final selected = selectedText.trim();
    if (selected.isNotEmpty) return selected;
    return (annotationText ?? '').trim();
  }

  bool get hasUsableText => primaryText.isNotEmpty;

  AnnotationAiContext copyWith({
    String? selectedText,
    String? materialId,
    String? lessonId,
    int? pageNumber,
    String? annotationText,
    String? surroundingText,
    bool clearSurrounding = false,
    String? annotationId,
    String? shortDescription,
    AiLanguage? language,
    TextDirection? direction,
    String? filePath,
    AiContextScope? contextScope,
    String? sourceTitle,
  }) {
    return AnnotationAiContext(
      selectedText: selectedText ?? this.selectedText,
      materialId: materialId ?? this.materialId,
      lessonId: lessonId ?? this.lessonId,
      pageNumber: pageNumber ?? this.pageNumber,
      annotationText: annotationText ?? this.annotationText,
      surroundingText: clearSurrounding
          ? null
          : (surroundingText ?? this.surroundingText),
      annotationId: annotationId ?? this.annotationId,
      shortDescription: shortDescription ?? this.shortDescription,
      language: language ?? this.language,
      direction: direction ?? this.direction,
      filePath: filePath ?? this.filePath,
      contextScope: contextScope ?? this.contextScope,
      sourceTitle: sourceTitle ?? this.sourceTitle,
    );
  }

  AiStudyRequest toStudyRequest({
    required AiStudyAction action,
    required AiExecutionSelection selection,
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
      selection: selection,
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
      surroundingLabel: usingImage ? null : contextScope.promptLabel,
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
