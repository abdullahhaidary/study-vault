import '../data/ai_settings_store.dart';
import '../domain/ai_exceptions.dart';

typedef GeminiRetryDelay = Future<void> Function(Duration duration);

abstract final class GeminiRetryPolicy {
  static const int defaultRetryCount = AiSettingsStore.defaultGeminiRetryCount;
  static const int maxRetryCount = AiSettingsStore.maxGeminiRetryCount;
  static const Duration _baseDelay = Duration(seconds: 2);
  static const Duration _maxDelay = Duration(seconds: 30);

  static Future<T> run<T>({
    required AiSettingsStore settings,
    required Future<T> Function() operation,
    GeminiRetryDelay delay = _delay,
  }) async {
    final retryCount = (await settings.getGeminiRetryCount())
        .clamp(0, maxRetryCount)
        .toInt();
    var failedAttempts = 0;

    while (true) {
      try {
        return await operation();
      } on AiException catch (error) {
        if (!_isRetryable(error) || failedAttempts >= retryCount) rethrow;
        await delay(_delayFor(failedAttempts));
        failedAttempts++;
      }
    }
  }

  static bool _isRetryable(AiException error) {
    return error is AiRateLimitException || error is AiQuotaException;
  }

  static Duration _delayFor(int failedAttempts) {
    final multiplier = 1 << failedAttempts;
    final milliseconds = _baseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds.clamp(0, _maxDelay.inMilliseconds).toInt(),
    );
  }

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);
}
