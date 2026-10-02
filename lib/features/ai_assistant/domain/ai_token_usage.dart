/// Provider-agnostic token / cache usage for one AI completion.
///
/// DeepSeek maps `prompt_cache_hit_tokens` / `prompt_cache_miss_tokens` into
/// [cacheHitTokens] / [cacheMissTokens]. Other providers may leave cache
/// fields null.
class AiTokenUsage {
  const AiTokenUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.cacheHitTokens,
    this.cacheMissTokens,
    this.model,
    this.provider,
    this.durationMs,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int? cacheHitTokens;
  final int? cacheMissTokens;
  final String? model;
  final String? provider;
  final int? durationMs;

  /// `hit / (hit + miss) * 100`, or null when the denominator is ≤ 0 / missing.
  double? get cacheHitRatio {
    final hit = cacheHitTokens;
    final miss = cacheMissTokens;
    if (hit == null && miss == null) return null;
    final h = hit ?? 0;
    final m = miss ?? 0;
    final denom = h + m;
    if (denom <= 0) return null;
    return h / denom * 100;
  }

  bool get hasAnyMetric =>
      promptTokens != null ||
      completionTokens != null ||
      totalTokens != null ||
      cacheHitTokens != null ||
      cacheMissTokens != null;

  AiTokenUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    int? cacheHitTokens,
    int? cacheMissTokens,
    String? model,
    String? provider,
    int? durationMs,
  }) {
    return AiTokenUsage(
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      cacheHitTokens: cacheHitTokens ?? this.cacheHitTokens,
      cacheMissTokens: cacheMissTokens ?? this.cacheMissTokens,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  /// Parses DeepSeek (and OpenAI-compatible) `usage` from a full response map.
  static AiTokenUsage? fromProviderResponse(
    Object? decoded, {
    String? model,
    String? provider,
    int? durationMs,
  }) {
    if (decoded is! Map) return null;
    return fromUsageMap(
      decoded['usage'],
      model: model,
      provider: provider,
      durationMs: durationMs,
    );
  }

  /// Parses Gemini `usageMetadata` from a generateContent response map.
  static AiTokenUsage? fromGeminiResponse(
    Object? decoded, {
    String? model,
    String? provider = 'gemini',
    int? durationMs,
  }) {
    if (decoded is! Map) return null;
    return fromGeminiUsageMap(
      decoded['usageMetadata'],
      model: model,
      provider: provider,
      durationMs: durationMs,
    );
  }

  static AiTokenUsage? fromGeminiUsageMap(
    Object? usage, {
    String? model,
    String? provider = 'gemini',
    int? durationMs,
  }) {
    if (usage is! Map) return null;
    final promptTokens = _readInt(usage['promptTokenCount']);
    final completionTokens =
        _readInt(usage['candidatesTokenCount']) ??
        _readInt(usage['completionTokenCount']);
    final totalTokens = _readInt(usage['totalTokenCount']);
    final cacheHit = _readInt(usage['cachedContentTokenCount']);

    if (promptTokens == null &&
        completionTokens == null &&
        totalTokens == null &&
        cacheHit == null) {
      return null;
    }

    return AiTokenUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      cacheHitTokens: cacheHit,
      cacheMissTokens: promptTokens != null && cacheHit != null
          ? (promptTokens - cacheHit).clamp(0, promptTokens)
          : null,
      model: model,
      provider: provider,
      durationMs: durationMs,
    );
  }

  /// Sums token fields across chunked requests (e.g. quiz generation).
  static AiTokenUsage? merge(Iterable<AiTokenUsage?> parts) {
    final list = [
      for (final p in parts)
        if (p != null && p.hasAnyMetric) p,
    ];
    if (list.isEmpty) return null;
    if (list.length == 1) return list.first;

    int? sum(int? Function(AiTokenUsage u) read) {
      var total = 0;
      var any = false;
      for (final u in list) {
        final v = read(u);
        if (v != null) {
          total += v;
          any = true;
        }
      }
      return any ? total : null;
    }

    return AiTokenUsage(
      promptTokens: sum((u) => u.promptTokens),
      completionTokens: sum((u) => u.completionTokens),
      totalTokens: sum((u) => u.totalTokens),
      cacheHitTokens: sum((u) => u.cacheHitTokens),
      cacheMissTokens: sum((u) => u.cacheMissTokens),
      model: list.last.model,
      provider: list.last.provider,
      durationMs: sum((u) => u.durationMs),
    );
  }

  static AiTokenUsage? fromUsageMap(
    Object? usage, {
    String? model,
    String? provider,
    int? durationMs,
  }) {
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

    return AiTokenUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      cacheHitTokens: hit,
      cacheMissTokens: miss,
      model: model,
      provider: provider,
      durationMs: durationMs,
    );
  }

  /// Compact label for chat bubbles, e.g. `15.9K tokens · 14K cached`.
  String get compactLabel {
    final total =
        totalTokens ??
        ((promptTokens ?? 0) + (completionTokens ?? 0) > 0
            ? (promptTokens ?? 0) + (completionTokens ?? 0)
            : null);
    final cached = cacheHitTokens;
    if (total != null && cached != null) {
      return '${formatCompactTokens(total)} tokens · ${formatCompactTokens(cached)} cached';
    }
    if (total != null) {
      final ratio = cacheHitRatio;
      if (ratio != null) {
        return '${formatCompactTokens(total)} tokens · ${ratio.toStringAsFixed(0)}% cache';
      }
      return '${formatCompactTokens(total)} tokens';
    }
    if (cached != null) {
      return '${formatCompactTokens(cached)} cached';
    }
    return 'Usage';
  }

  /// Development log. Never includes keys, headers, or prompt text.
  String formatLog() {
    final ratio = cacheHitRatio;
    final buffer = StringBuffer()
      ..writeln('DeepSeek usage')
      ..writeln('Model: ${model ?? 'n/a'}')
      ..writeln('Prompt tokens: ${_fmtExact(promptTokens)}')
      ..writeln('Cache hit tokens: ${_fmtExact(cacheHitTokens)}')
      ..writeln('Cache miss tokens: ${_fmtExact(cacheMissTokens)}')
      ..writeln('Completion tokens: ${_fmtExact(completionTokens)}')
      ..writeln('Total tokens: ${_fmtExact(totalTokens)}')
      ..writeln(
        'Cache hit ratio: ${ratio == null ? 'n/a' : '${ratio.toStringAsFixed(1)}%'}',
      );
    if (durationMs != null) {
      buffer.writeln('Request duration: ${durationMs}ms');
    }
    return buffer.toString().trimRight();
  }

  static String formatCompactTokens(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final k = value / 1000;
      if ((k - k.round()).abs() < 0.05) return '${k.round()}K';
      return '${k.toStringAsFixed(1)}K';
    }
    final m = value / 1000000;
    if ((m - m.round()).abs() < 0.05) return '${m.round()}M';
    return '${m.toStringAsFixed(1)}M';
  }

  static String formatExactTokens(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String formatDuration(int? ms) {
    if (ms == null) return 'n/a';
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(seconds >= 10 ? 1 : 1)} s';
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _fmtExact(int? value) {
    if (value == null) return 'n/a';
    return formatExactTokens(value);
  }
}

void logAiTokenUsage(AiTokenUsage? usage) {
  assert(() {
    final text = (usage ?? const AiTokenUsage()).formatLog();
    // ignore: avoid_print
    print(text);
    return true;
  }());
}

/// Backward-compatible alias used by earlier DeepSeek logging helpers.
typedef DeepSeekPromptUsage = AiTokenUsage;

void logDeepSeekUsage({
  required String model,
  required AiTokenUsage? usage,
  int? durationMs,
}) {
  logAiTokenUsage(
    (usage ?? const AiTokenUsage()).copyWith(
      model: model,
      durationMs: durationMs ?? usage?.durationMs,
      provider: usage?.provider ?? 'deepseek',
    ),
  );
}
