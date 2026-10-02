/// Token usage from a DeepSeek Chat Completions `usage` object.
///
/// Official fields: `prompt_tokens`, `completion_tokens`, `total_tokens`,
/// `prompt_cache_hit_tokens`, `prompt_cache_miss_tokens`.
/// Also accepts nested `prompt_tokens_details.cached_tokens` used by some
/// OpenAI-compatible gateways.
class DeepSeekPromptUsage {
  const DeepSeekPromptUsage({
    this.promptTokens,
    this.promptCacheHitTokens,
    this.promptCacheMissTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final int? promptTokens;
  final int? promptCacheHitTokens;
  final int? promptCacheMissTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// `hit / (hit + miss) * 100`, or null when the denominator is 0 or missing.
  double? get cacheHitRatioPercent {
    final hit = promptCacheHitTokens;
    final miss = promptCacheMissTokens;
    if (hit == null && miss == null) return null;
    final h = hit ?? 0;
    final m = miss ?? 0;
    final denom = h + m;
    if (denom <= 0) return null;
    return h / denom * 100;
  }

  static DeepSeekPromptUsage? fromResponse(Object? decoded) {
    if (decoded is! Map) return null;
    return fromUsageMap(decoded['usage']);
  }

  static DeepSeekPromptUsage? fromUsageMap(Object? usage) {
    if (usage is! Map) return null;

    final promptTokens = _readInt(usage['prompt_tokens']);
    final completionTokens = _readInt(usage['completion_tokens']);
    final totalTokens = _readInt(usage['total_tokens']);

    var hit =
        _readInt(usage['prompt_cache_hit_tokens']) ??
        _readInt(usage['cache_hit_tokens']);
    var miss =
        _readInt(usage['prompt_cache_miss_tokens']) ??
        _readInt(usage['cache_miss_tokens']);

    final details = usage['prompt_tokens_details'];
    if (details is Map) {
      hit ??= _readInt(details['cached_tokens']);
    }

    if (hit != null && miss == null && promptTokens != null) {
      miss = (promptTokens - hit).clamp(0, promptTokens);
    }
    if (miss != null && hit == null && promptTokens != null) {
      hit = (promptTokens - miss).clamp(0, promptTokens);
    }

    if (promptTokens == null &&
        hit == null &&
        miss == null &&
        completionTokens == null &&
        totalTokens == null) {
      return null;
    }

    return DeepSeekPromptUsage(
      promptTokens: promptTokens,
      promptCacheHitTokens: hit,
      promptCacheMissTokens: miss,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  /// Development log line. Never includes keys, headers, or prompt text.
  String formatLog({required String model, int? durationMs}) {
    final ratio = cacheHitRatioPercent;
    final buffer = StringBuffer()
      ..writeln('DeepSeek usage')
      ..writeln('Model: $model')
      ..writeln('Prompt tokens: ${_fmt(promptTokens)}')
      ..writeln('Cache hit tokens: ${_fmt(promptCacheHitTokens)}')
      ..writeln('Cache miss tokens: ${_fmt(promptCacheMissTokens)}')
      ..writeln('Completion tokens: ${_fmt(completionTokens)}')
      ..writeln('Total tokens: ${_fmt(totalTokens)}')
      ..writeln(
        'Cache hit ratio: ${ratio == null ? 'n/a' : '${ratio.toStringAsFixed(1)}%'}',
      );
    if (durationMs != null) {
      buffer.writeln('Request duration: ${durationMs}ms');
    }
    return buffer.toString().trimRight();
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _fmt(int? value) {
    if (value == null) return 'n/a';
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

void logDeepSeekUsage({
  required String model,
  required DeepSeekPromptUsage? usage,
  int? durationMs,
}) {
  assert(() {
    final text = (usage ?? const DeepSeekPromptUsage()).formatLog(
      model: model,
      durationMs: durationMs,
    );
    // ignore: avoid_print
    print(text);
    return true;
  }());
}
