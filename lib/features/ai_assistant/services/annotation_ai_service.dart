import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
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
    this.cacheTtl = const Duration(minutes: 5),
    this.maxCacheEntries = 24,
  }) : _ai = aiService;

  final AiService _ai;
  final Duration cacheTtl;
  final int maxCacheEntries;

  final Map<String, _CacheEntry> _cache = {};
  Future<AiStudyResult>? _inFlight;
  String? _inFlightKey;

  Future<bool> get isConfigured => _ai.isConfigured;

  /// Runs a study action for [context].
  Future<AiStudyResult> run({
    required AnnotationAiContext context,
    required AiStudyAction action,
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
    Duration timeout = const Duration(seconds: 60),
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

    final key = _cacheKey(request);
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
    if (_inFlight != null && _inFlightKey == key) {
      return _inFlight!;
    }

    final future = _ai.run(
      request,
      categoryNameToId: categoryNameToId,
      timeout: timeout,
    );
    _inFlight = future;
    _inFlightKey = key;

    try {
      final result = await future;
      if (useCache &&
          action.isCacheable &&
          conversation.isEmpty &&
          (customPrompt == null || customPrompt.trim().isEmpty)) {
        _putCache(key, result);
      }
      return result;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
        _inFlightKey = null;
      }
    }
  }

  /// Follow-up turn keeping the original annotation context.
  Future<AiTextResult> followUp({
    required AnnotationAiContext context,
    required List<AiConversationTurn> conversation,
    required String userMessage,
    Map<String, String> categoryNameToId = const {},
  }) async {
    final result = await run(
      context: context,
      action: AiStudyAction.askAi,
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

  void clearCache() => _cache.clear();

  String _cacheKey(AiStudyRequest request) {
    return [
      request.action.name,
      request.language.name,
      request.rephraseMode?.name ?? '',
      request.organizeMode?.name ?? '',
      request.summarizeMode?.name ?? '',
      request.translateTarget?.name ?? '',
      '${request.flashcardCount}',
      request.sourceText,
      request.surroundingText ?? '',
      request.customPrompt ?? '',
      request.pageNumber?.toString() ?? '',
      request.pageSendMode.name,
      request.hasPageImage ? 'img' : '',
    ].join('\u001f');
  }

  void _putCache(String key, AiStudyResult result) {
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
