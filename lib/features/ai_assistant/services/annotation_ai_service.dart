import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/ai_endpoint_profile_repository.dart';
import '../data/ai_settings_store.dart';
import 'ai_prompt_builder.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_models.dart';
import '../domain/annotation_ai_context.dart';
import '../../ai_questions/services/pdf_page_image_extractor.dart';
import 'ai_service.dart';

/// Domain façade for annotation / selection AI.
///
/// Builds normalized [AiStudyRequest] values and delegates to the shared
/// [AiService] (Gemini). Includes light in-memory dedupe for identical runs.
class AnnotationAiService {
  AnnotationAiService({
    required AiService aiService,
    this.settings,
    this.profiles,
    this.cacheTtl = const Duration(minutes: 5),
    this.maxCacheEntries = 24,
  }) : _ai = aiService;

  final AiService _ai;
  final AiSettingsStore? settings;
  final AiEndpointProfileRepository? profiles;
  final Duration cacheTtl;
  final int maxCacheEntries;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<AiStudyResult>> _inFlight = {};
  int _cacheEpoch = 0;

  Future<bool> get isConfigured => _ai.isConfigured;

  /// Runs a study action for [context].
  Future<AiStudyResult> run({
    required AnnotationAiContext context,
    required AiStudyAction action,
    required AiExecutionSelection selection,
    AiRephraseMode? rephraseMode,
    AiOrganizeMode? organizeMode,
    AiSummarizeMode? summarizeMode,
    int flashcardCount = 5,
    List<String> categoryNames = const [],
    String? customPrompt,
    List<AiConversationTurn> conversation = const [],
    AiLanguage? translateTarget,
    AiLanguage? languageOverride,
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(minutes: 5),
    bool useCache = true,
    AiPageSendMode sendMode = AiPageSendMode.text,
    AiStudyImage? image,
  }) async {
    AiStudyImage? resolvedImage = image;
    if (sendMode == AiPageSendMode.image && resolvedImage == null) {
      final path = context.filePath;
      final page = context.pageNumber;
      if (path == null || page == null) {
        throw const AiMalformedOutputException(
          'No PDF page available to send as an image.',
        );
      }
      resolvedImage = await PdfPageImageExtractor.renderJpeg(
        filePath: path,
        pageNumber: page,
      );
    }

    if (!context.hasUsableText && resolvedImage == null) {
      throw const AiEmptySelectionException();
    }

    final request = context.toStudyRequest(
      action: action,
      selection: selection,
      userPreference: settings == null
          ? null
          : (await settings!.styleForSend(provider: selection.provider) ?? ''),
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      flashcardCount: flashcardCount,
      categoryNames: categoryNames,
      customPrompt: customPrompt,
      conversation: conversation,
      translateTarget: translateTarget,
      languageOverride: languageOverride,
      pageSendMode: resolvedImage == null
          ? AiPageSendMode.text
          : AiPageSendMode.image,
      image: resolvedImage,
    );

    if (resolvedImage == null &&
        request.effectiveSourceLength > kAiHardSourceLimit) {
      throw const AiSourceTooLargeException();
    }

    final profileId = request.selection.endpointProfileId;
    final profile = profileId == null ? null : await profiles?.find(profileId);
    if (profileId != null &&
        profiles != null &&
        (profile == null || !profile.enabled)) {
      throw const AiProfileUnavailableException();
    }
    final key = _cacheKey(
      request,
      categoryNameToId,
      profile?.connectionRevision,
      (await settings?.getThinkingMode())?.name,
      timeout,
    );
    final epoch = _cacheEpoch;
    if (useCache &&
        action.isCacheable &&
        conversation.isEmpty &&
        (customPrompt == null || customPrompt.trim().isEmpty)) {
      final hit = _cache[key];
      if (hit != null && DateTime.now().difference(hit.at) < cacheTtl) {
        return hit.result;
      }
    }

    // Collapse accidental double-taps of the same request.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _ai.run(
      request,
      categoryNameToId: categoryNameToId,
      timeout: timeout,
    );
    _inFlight[key] = future;

    try {
      final result = await future;
      if (useCache &&
          epoch == _cacheEpoch &&
          !(result is AiTextResult &&
              result.disposition != AiCompletionDisposition.complete) &&
          action.isCacheable &&
          conversation.isEmpty &&
          (customPrompt == null || customPrompt.trim().isEmpty)) {
        _putCache(key, result);
      }
      return result;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  /// Follow-up turn keeping the original annotation context.
  Future<AiTextResult> followUp({
    required AnnotationAiContext context,
    required AiExecutionSelection selection,
    required List<AiConversationTurn> conversation,
    required String userMessage,
    Map<String, String> categoryNameToId = const {},
  }) async {
    final result = await run(
      context: context,
      action: AiStudyAction.askAi,
      selection: selection,
      customPrompt: userMessage,
      conversation: conversation,
      categoryNameToId: categoryNameToId,
      useCache: false,
    );
    if (result is! AiTextResult) {
      throw const AiMalformedOutputException(
        'AI follow-up did not return text.',
      );
    }
    return result;
  }

  void clearCache() {
    _cache.clear();
    _cacheEpoch++;
  }

  String _cacheKey(
    AiStudyRequest request,
    Map<String, String> categoryNameToId,
    int? connectionRevision,
    String? thinkingMode,
    Duration timeout,
  ) {
    final categoryIds = categoryNameToId.keys.toList()..sort();
    // Canonical structured encoding avoids delimiter collisions. Hashes bound
    // memory usage and keep source text out of map keys and diagnostics.
    final identity = {
      'v': 2,
      'model': request.selection.modelRef.storageValue,
      'resolvedModel': request.selection.resolvedModelId,
      'connectionRevision': connectionRevision,
      'thinking': request.selection.thinkingMode?.name ?? thinkingMode,
      'prompt': AiPromptBuilder.forRequest(request),
      'conversation': [
        for (final turn in request.conversation)
          [turn.userMessage, turn.assistantMarkdown],
      ],
      'categories': [
        for (final name in categoryIds) [name, categoryNameToId[name]],
      ],
      'source': request.sourceText,
      'selected': request.selectedText,
      'shortDescription': request.shortDescription,
      'surroundingLabel': request.surroundingLabel,
      'pageSendMode': request.pageSendMode.name,
      'image': request.image == null
          ? null
          : {
              'sha256': sha256.convert(request.image!.bytes).toString(),
              'mimeType': request.image!.mimeType,
              'page': request.image!.pageNumber,
            },
      'timeoutMicros': timeout.inMicroseconds,
    };
    return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
  }

  void _putCache(String key, AiStudyResult result) {
    if (maxCacheEntries <= 0) return;
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.difference(entry.at) >= cacheTtl);
    _cache[key] = _CacheEntry(at: DateTime.now(), result: result);
    if (_cache.length <= maxCacheEntries) return;
    final oldest = _cache.entries.reduce(
      (a, b) => a.value.at.isBefore(b.value.at) ? a : b,
    );
    _cache.remove(oldest.key);
  }
}

class _CacheEntry {
  const _CacheEntry({required this.at, required this.result});
  final DateTime at;
  final AiStudyResult result;
}
