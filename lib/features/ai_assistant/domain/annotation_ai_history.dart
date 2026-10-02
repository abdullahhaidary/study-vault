import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'ai_actions.dart';
import 'ai_models.dart';
import 'annotation_ai_context.dart';

/// Prompt template versions stored with each generation (for debugging).
abstract final class AnnotationAiPromptVersions {
  static const explain = 'annotation_explain_v1';
  static const simplify = 'annotation_simplify_v1';
  static const summarize = 'annotation_summary_v1';
  static const define = 'annotation_define_v1';
  static const giveExample = 'annotation_example_v1';
  static const translate = 'annotation_translate_v1';
  static const rephrase = 'annotation_rephrase_v1';
  static const fixGrammar = 'annotation_fix_grammar_v1';
  static const organize = 'annotation_organize_v1';
  static const askAi = 'annotation_ask_v1';
  static const customPrompt = 'annotation_custom_v1';
  static const createAnnotation = 'annotation_create_v1';
  static const generateFlashcards = 'annotation_flashcards_v1';
  static const generateQuestions = 'annotation_questions_v1';
  static const keyConcepts = 'annotation_key_concepts_v1';
  static const examPoints = 'annotation_exam_points_v1';

  static String forAction(AiStudyAction action) => switch (action) {
    AiStudyAction.explain => explain,
    AiStudyAction.simplify => simplify,
    AiStudyAction.summarize => summarize,
    AiStudyAction.define => define,
    AiStudyAction.giveExample => giveExample,
    AiStudyAction.translate => translate,
    AiStudyAction.rephrase => rephrase,
    AiStudyAction.fixGrammar => fixGrammar,
    AiStudyAction.organize => organize,
    AiStudyAction.askAi => askAi,
    AiStudyAction.customPrompt => customPrompt,
    AiStudyAction.createAnnotation => createAnnotation,
    AiStudyAction.generateFlashcards => generateFlashcards,
    AiStudyAction.generateQuestions => generateQuestions,
    AiStudyAction.keyConcepts => keyConcepts,
    AiStudyAction.examPoints => examPoints,
  };
}

/// Stable fingerprint grouping generations for one source + scope.
abstract final class AnnotationAiSourceFingerprint {
  /// Prefer annotation id when present; otherwise material/page + text hash.
  static String from({
    String? annotationId,
    String? materialId,
    int? pageNumber,
    required String inputText,
  }) {
    final annotation = annotationId?.trim();
    if (annotation != null && annotation.isNotEmpty) {
      return 'ann:$annotation';
    }
    final digest = sha256.convert(utf8.encode(inputText.trim())).toString();
    final short = digest.substring(0, 16);
    final material = materialId?.trim() ?? '';
    final page = pageNumber?.toString() ?? '';
    return 'sel:$material:$page:$short';
  }

  static String fromContext(AnnotationAiContext context) {
    return from(
      annotationId: context.annotationId,
      materialId: context.materialId,
      pageNumber: context.pageNumber,
      inputText: context.primaryText,
    );
  }

  static String fromRequest(AiStudyRequest request) {
    return from(
      annotationId: request.annotationId,
      materialId: request.materialId,
      pageNumber: request.pageNumber,
      inputText: request.sourceText,
    );
  }
}

/// Optional mode snapshot stored with a generation.
String? annotationAiActionMode({
  AiRephraseMode? rephraseMode,
  AiOrganizeMode? organizeMode,
  AiSummarizeMode? summarizeMode,
  AiLanguage? translateTarget,
}) {
  if (rephraseMode != null) return 'rephrase:${rephraseMode.name}';
  if (organizeMode != null) return 'organize:${organizeMode.name}';
  if (summarizeMode != null) return 'summarize:${summarizeMode.name}';
  if (translateTarget != null) return 'translate:${translateTarget.name}';
  return null;
}
