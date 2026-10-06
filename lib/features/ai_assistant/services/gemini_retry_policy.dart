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
  }) {
    return runWithKeys(
      settings: settings,
      keys: const [''],
      delay: delay,
      operation: (_) => operation(),
    );
  }

  /// Tries each Gemini key in order. Quota, rate-limit, invalid-key, and
  /// similar account failures move to the next key immediately. After every
  /// key has failed, the configured retry count repeats the whole list.
  static Future<T> runWithKeys<T>({
    required AiSettingsStore settings,
    required List<String> keys,
    required Future<T> Function(String apiKey) operation,
    GeminiRetryDelay delay = _delay,
  }) async {
    if (keys.isEmpty) {
      throw const AiNotConfiguredException(
        'Gemini is not configured yet. Add an API key in Settings.',
      );
    }
    final retryCount = (await settings.getGeminiRetryCount())
        .clamp(0, maxRetryCount)
        .toInt();
    var failedRounds = 0;
    AiException? lastFailover;

    while (true) {
      for (final key in keys) {
        try {
          return await operation(key);
        } on AiException catch (error) {
          if (!_shouldFailover(error)) rethrow;
          lastFailover = error;
        }
      }
      if (failedRounds >= retryCount ||
          (lastFailover != null && !_shouldRetryRound(lastFailover))) {
        throw lastFailover ??
            const AiNotConfiguredException(
              'Gemini is not configured yet. Add an API key in Settings.',
            );
      }
      await delay(_delayFor(failedRounds));
      failedRounds++;
    }
  }

  static bool _shouldFailover(AiException error) {
    return error is AiRateLimitException ||
        error is AiQuotaException ||
        error is AiInvalidKeyException ||
        error is AiUnsupportedModelException ||
        error is AiServerException ||
        error is AiTimeoutException;
  }

  static bool _shouldRetryRound(AiException error) {
    return error is AiRateLimitException ||
        error is AiQuotaException ||
        error is AiServerException ||
        error is AiTimeoutException;
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
