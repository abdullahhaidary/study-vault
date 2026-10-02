import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';
import '../domain/ai_token_usage.dart';
import '../domain/annotation_ai_context.dart';
import '../domain/annotation_ai_history.dart';
import 'annotation_ai_service.dart';

/// Persists immutable AI generation versions for annotation/selection flows.
class AnnotationAiHistoryService {
  AnnotationAiHistoryService({
    required AppDatabase db,
    required AnnotationAiService aiService,
    Uuid? uuid,
  }) : _db = db,
       _ai = aiService,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AnnotationAiService _ai;
  final Uuid _uuid;

  Future<bool> get isConfigured => _ai.isConfigured;

  String fingerprintFor({
    AnnotationAiContext? context,
    AiStudyRequest? request,
  }) {
    if (context != null) {
      return AnnotationAiSourceFingerprint.fromContext(context);
    }
    if (request != null) {
      return AnnotationAiSourceFingerprint.fromRequest(request);
    }
    throw ArgumentError('context or request is required');
  }

  Future<Map<AiStudyAction, int>> getGenerationCounts({
    required String sourceFingerprint,
  }) async {
    final raw = await _db.countAiGenerationsByAction(sourceFingerprint);
    return {
      for (final entry in raw.entries) ?_tryParseAction(entry.key): entry.value,
    };
  }

  Future<List<AnnotationAiGeneration>> getGenerations({
    required String sourceFingerprint,
    required AiStudyAction action,
  }) {
    return _db.listAiGenerations(
      sourceFingerprint: sourceFingerprint,
      actionType: action.name,
    );
  }

  Future<List<AnnotationAiGeneration>> getAllGenerationsForAnnotation(
    String annotationId,
  ) {
    return _db.listAiGenerationsForAnnotation(annotationId);
  }

  Future<AnnotationAiGeneration?> getGeneration(String id) {
    return _db.getAiGenerationById(id);
  }

  /// Runs the active AI provider and persists a new immutable generation
  /// (never overwrites).
  Future<AnnotationAiGeneration> generate({
    required AnnotationAiContext context,
    required AiStudyAction action,
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    AiLanguage? translateTarget,
    String? customPrompt,
    List<AiConversationTurn> conversation = const [],
    int flashcardCount = 5,
    List<String> categoryNames = const [],
    Map<String, String> categoryNameToId = const {},
    String? parentGenerationId,
    String? modelName,
    String? provider,
    bool useCache = false,
    AiPageSendMode sendMode = AiPageSendMode.text,
  }) async {
    final result = await _ai.run(
      context: context,
      action: action,
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      translateTarget: translateTarget,
      customPrompt: customPrompt,
      conversation: conversation,
      flashcardCount: flashcardCount,
      categoryNames: categoryNames,
      categoryNameToId: categoryNameToId,
      useCache: useCache,
      sendMode: sendMode,
    );

    final persisted = _serializeResult(result);
    if (persisted == null) {
      throw StateError('AI result could not be persisted as history');
    }

    return persistCompleted(
      context: context,
      action: action,
      responseText: persisted.text,
      responseKind: persisted.kind,
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      translateTarget: translateTarget,
      customPrompt: customPrompt,
      parentGenerationId: parentGenerationId,
      modelName: modelName,
      provider: provider,
      linkedQuestionSetId: persisted.linkedQuestionSetId,
      usage: result.usage,
    );
  }

  /// Persist an already-completed AI result as a new version.
  Future<AnnotationAiGeneration> persistCompleted({
    required AnnotationAiContext context,
    required AiStudyAction action,
    required String responseText,
    String responseKind = 'text',
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    AiLanguage? translateTarget,
    String? customPrompt,
    String? parentGenerationId,
    String? modelName,
    String? provider,
    String? linkedQuestionSetId,
    String? linkedFlashcardBatchId,
    AiTokenUsage? usage,
  }) {
    final fingerprint = AnnotationAiSourceFingerprint.fromContext(context);
    final now = DateTime.now();
    final id = _uuid.v4();
    final mode = annotationAiActionMode(
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      translateTarget: translateTarget,
    );

    return _db.insertAiGeneration(
      sourceFingerprint: fingerprint,
      actionType: action.name,
      builder: (generationNumber) => AnnotationAiGenerationsCompanion.insert(
        id: id,
        annotationId: Value(context.annotationId),
        materialId: Value(context.materialId),
        lessonId: Value(context.lessonId),
        pageNumber: Value(context.pageNumber),
        sourceFingerprint: fingerprint,
        actionType: action.name,
        inputText: context.primaryText,
        contextSnapshot: Value(
          _truncate(context.surroundingText, kAiSurroundingContextLimit),
        ),
        customPrompt: Value(customPrompt),
        actionMode: Value(mode),
        responseText: responseText,
        responseKind: Value(responseKind),
        language: Value(context.language.name),
        modelName: Value(modelName ?? usage?.model),
        provider: Value(provider ?? usage?.provider ?? 'gemini'),
        promptVersion: Value(AnnotationAiPromptVersions.forAction(action)),
        parentGenerationId: Value(parentGenerationId),
        generationNumber: generationNumber,
        linkedQuestionSetId: Value(linkedQuestionSetId),
        linkedFlashcardBatchId: Value(linkedFlashcardBatchId),
        promptTokens: Value(usage?.promptTokens),
        completionTokens: Value(usage?.completionTokens),
        totalTokens: Value(usage?.totalTokens),
        cacheHitTokens: Value(usage?.cacheHitTokens),
        cacheMissTokens: Value(usage?.cacheMissTokens),
        requestDurationMs: Value(usage?.durationMs),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<AnnotationAiGeneration> regenerate({
    required AnnotationAiContext context,
    required AiStudyAction action,
    AnnotationAiGeneration? parent,
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    AiLanguage? translateTarget,
    String? customPrompt,
    String? regenerateInstruction,
    Map<String, String> categoryNameToId = const {},
    String? modelName,
    String? provider,
    AiPageSendMode sendMode = AiPageSendMode.text,
  }) {
    final instruction = regenerateInstruction?.trim();
    final existing = customPrompt?.trim();
    final mergedPrompt = switch ((existing, instruction)) {
      (final c?, final i?) when c.isNotEmpty && i.isNotEmpty => '$c\n\n$i',
      (_, final i?) when i.isNotEmpty => i,
      (final c?, _) when c.isNotEmpty => c,
      _ => null,
    };

    // Prefer modes stored on the parent generation when regenerating.
    final parentMode = parent?.actionMode;
    final resolvedSummarize = summarizeMode ?? _parseSummarizeMode(parentMode);
    final resolvedRephrase = rephraseMode ?? _parseRephraseMode(parentMode);
    final resolvedOrganize = organizeMode ?? _parseOrganizeMode(parentMode);
    final resolvedTranslate =
        translateTarget ?? _parseTranslateTarget(parentMode);

    return generate(
      context: context,
      action: action,
      rephraseMode: resolvedRephrase,
      organizeMode: resolvedOrganize,
      summarizeMode: resolvedSummarize,
      translateTarget: resolvedTranslate,
      customPrompt: mergedPrompt ?? parent?.customPrompt,
      parentGenerationId: parent?.id,
      categoryNameToId: categoryNameToId,
      modelName: modelName,
      provider: provider,
      useCache: false,
      sendMode: sendMode,
    );
  }

  Future<void> deleteGeneration(String id) => _db.deleteAiGeneration(id);

  Future<int> deleteAllForAction({
    required String sourceFingerprint,
    required AiStudyAction action,
  }) {
    return _db.deleteAiGenerationsForAction(
      sourceFingerprint: sourceFingerprint,
      actionType: action.name,
    );
  }

  static AiStudyAction? _tryParseAction(String name) {
    for (final action in AiStudyAction.values) {
      if (action.name == name) return action;
    }
    return null;
  }

  static String? _truncate(String? value, int max) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= max) return trimmed;
    return trimmed.substring(0, max);
  }

  static ({String text, String kind, String? linkedQuestionSetId})?
  _serializeResult(AiStudyResult result) {
    return switch (result) {
      AiTextResult(:final markdown) => (
        text: markdown,
        kind: 'text',
        linkedQuestionSetId: null,
      ),
      AiAnnotationDraft(
        :final shortDescription,
        :final fullNoteMarkdown,
        :final suggestedCategory,
      ) =>
        (
          text: suggestedCategory == null
              ? '## $shortDescription\n\n$fullNoteMarkdown'
              : '## $shortDescription\n\n$fullNoteMarkdown\n\n'
                    'Category: $suggestedCategory',
          kind: 'annotation',
          linkedQuestionSetId: null,
        ),
      AiFlashcardsResult(:final cards) => (
        text: cards
            .map((c) => 'Q: ${c.front}\nA: ${c.back}')
            .join('\n\n---\n\n'),
        kind: 'flashcards',
        linkedQuestionSetId: null,
      ),
      AiQuestionsResult(:final title, :final questions) => (
        text:
            '## $title\n\n'
            '${questions.map((q) => '- ${q.question}').join('\n')}',
        kind: 'questions',
        linkedQuestionSetId: null,
      ),
    };
  }

  static AiSummarizeMode? _parseSummarizeMode(String? mode) {
    if (mode == null || !mode.startsWith('summarize:')) return null;
    final name = mode.substring('summarize:'.length);
    for (final m in AiSummarizeMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  static AiRephraseMode? _parseRephraseMode(String? mode) {
    if (mode == null || !mode.startsWith('rephrase:')) return null;
    final name = mode.substring('rephrase:'.length);
    for (final m in AiRephraseMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  static AiOrganizeMode? _parseOrganizeMode(String? mode) {
    if (mode == null || !mode.startsWith('organize:')) return null;
    final name = mode.substring('organize:'.length);
    for (final m in AiOrganizeMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  static AiLanguage? _parseTranslateTarget(String? mode) {
    if (mode == null || !mode.startsWith('translate:')) return null;
    final name = mode.substring('translate:'.length);
    for (final m in AiLanguage.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
