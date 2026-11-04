import '../../ai_assistant/data/ai_request_metrics_store.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

/// Measures end-to-end time and streamed first-token latency without retaining
/// conversation content. It does not issue requests or retries of its own.
class MeasuredAiChatTransport implements AiChatTransport {
  MeasuredAiChatTransport(this.inner, this.metrics);
  final AiChatTransport inner;
  final AiRequestMetricsStore metrics;
  @override
  Future<bool> get isConfigured => inner.isConfigured;
  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) => inner.listAvailableChatModels(timeout: timeout);

  Future<void> _record(
    String modelId,
    Stopwatch watch,
    AiTokenUsage? usage,
    bool ok,
    int? firstMs,
  ) async {
    try {
      await metrics.add(
        AiRequestMetric(
          modelId: modelId,
          at: DateTime.now(),
          succeeded: ok,
          usage: (usage ?? const AiTokenUsage()).copyWith(
            model: modelId,
            provider:
                usage?.provider ??
                AiProviderIdX.fromModelId(modelId).storageValue,
            durationMs: watch.elapsedMilliseconds,
            timeToFirstTokenMs: firstMs,
          ),
        ),
      );
    } on Object {
      /* Diagnostics must not fail a successful request. */
    }
  }

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
    String? pocketChatId,
  }) async {
    final watch = Stopwatch()..start();
    AiTokenUsage? usage;
    var ok = false;
    try {
      final result = await inner.complete(
        modelId: modelId,
        history: history,
        timeout: timeout,
        pocketChatId: pocketChatId,
      );
      usage = result.usage;
      ok = true;
      return AiChatCompletion(
        text: result.text,
        modelId: result.modelId,
        pocketChatId: result.pocketChatId,
        usage: (usage ?? const AiTokenUsage()).copyWith(
          durationMs: watch.elapsedMilliseconds,
        ),
      );
    } finally {
      await _record(modelId, watch, usage, ok, null);
    }
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
    String? pocketChatId,
  }) async* {
    final watch = Stopwatch()..start();
    AiTokenUsage? usage;
    int? firstMs;
    var ok = false;
    try {
      await for (final event in inner.streamComplete(
        modelId: modelId,
        history: history,
        timeout: timeout,
        pocketChatId: pocketChatId,
      )) {
        if (event.textDelta?.isNotEmpty == true) {
          firstMs ??= watch.elapsedMilliseconds;
        }
        usage = event.usage ?? usage;
        yield AiChatStreamEvent(
          textDelta: event.textDelta,
          pocketChatId: event.pocketChatId,
          usage: event.usage?.copyWith(timeToFirstTokenMs: firstMs),
        );
      }
      ok = true;
      yield AiChatStreamEvent(
        usage: (usage ?? const AiTokenUsage()).copyWith(
          model: modelId,
          provider:
              usage?.provider ??
              AiProviderIdX.fromModelId(modelId).storageValue,
          durationMs: watch.elapsedMilliseconds,
          timeToFirstTokenMs: firstMs,
        ),
      );
    } finally {
      await _record(modelId, watch, usage, ok, firstMs);
    }
  }
}
