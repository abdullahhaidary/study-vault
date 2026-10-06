import 'dart:convert';

import 'ai_exceptions.dart';
import 'ai_provider.dart';

class AiStyleMemoryItem {
  const AiStyleMemoryItem({required this.id, required this.text});

  final String id;
  final String text;

  AiStyleMemoryItem copyWith({String? text}) {
    return AiStyleMemoryItem(id: id, text: text ?? this.text);
  }
}

/// Compact hidden style notes prepended to AI system prompts.
///
/// Gemini, DeepSeek, and Claude reuse a stable prefix, so a modest STYLE block
/// is cheap after the first request. The uncached cap is for a cache miss
/// (you edited notes, or the provider does not cache).
abstract final class AiStyleMemory {
  /// Paid in full on a cache miss. Keep notes under this when you edit often.
  static const uncachedTokenBudget = 192;

  /// Allowed when the provider caches the system prefix (typical here).
  static const cachedTokenBudget = 384;

  static const maxItemChars = 96;
  static const header = 'STYLE:';

  static bool usesPrefixCache(AiProviderId provider) => switch (provider) {
    AiProviderId.gemini || AiProviderId.deepseek || AiProviderId.newApi => true,
  };

  static int budgetFor({required bool prefixCacheLikely}) =>
      prefixCacheLikely ? cachedTokenBudget : uncachedTokenBudget;

  /// Conservative: ASCII ~4 chars/token, other scripts denser.
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    var weighted = 0.0;
    for (final rune in text.runes) {
      weighted += rune <= 0x7F ? 0.25 : 0.55;
    }
    final tokens = weighted.ceil();
    return tokens < 1 ? 1 : tokens;
  }

  static String normalizeItemText(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? compact(List<AiStyleMemoryItem> items) {
    final lines = [
      for (final item in items) normalizeItemText(item.text),
    ].where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    return '$header\n${lines.map((line) => '- $line').join('\n')}';
  }

  static String appendToSystem(String system, String? styleBlock) {
    final block = styleBlock?.trim();
    if (block == null || block.isEmpty) return system;
    return '${system.trimRight()}\n$block';
  }

  static void ensureFits(
    String? styleBlock, {
    required bool prefixCacheLikely,
  }) {
    final block = styleBlock?.trim();
    if (block == null || block.isEmpty) return;
    final tokens = estimateTokens(block);
    final budget = budgetFor(prefixCacheLikely: prefixCacheLikely);
    if (tokens > budget) {
      throw AiStyleMemoryTooLargeException(tokens: tokens, budget: budget);
    }
  }

  static void ensureFitsForSave(List<AiStyleMemoryItem> items) {
    for (final item in items) {
      final text = normalizeItemText(item.text);
      if (text.length > maxItemChars) {
        throw AiStyleMemoryTooLargeException.itemTooLong(maxItemChars);
      }
    }
    ensureFits(compact(items), prefixCacheLikely: true);
  }

  static String? forSend(
    List<AiStyleMemoryItem> items, {
    required bool prefixCacheLikely,
  }) {
    final block = compact(items);
    ensureFits(block, prefixCacheLikely: prefixCacheLikely);
    return block;
  }

  static List<AiStyleMemoryItem> itemsFromStoredBlob(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const [];
    if (text.startsWith(header)) {
      final bullets = <AiStyleMemoryItem>[];
      for (final line in text.split('\n').skip(1)) {
        final cleaned = normalizeItemText(
          line.replaceFirst(RegExp(r'^[-*]\s*'), ''),
        );
        if (cleaned.isEmpty) continue;
        bullets.add(
          AiStyleMemoryItem(id: 'm${bullets.length + 1}', text: cleaned),
        );
      }
      if (bullets.isNotEmpty) return bullets;
    }
    return [AiStyleMemoryItem(id: 'legacy', text: normalizeItemText(text))];
  }

  static List<AiStyleMemoryItem> decodeJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final items = <AiStyleMemoryItem>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final text = entry['t'] ?? entry['text'];
      if (id is! String || id.isEmpty || text is! String) continue;
      final cleaned = normalizeItemText(text);
      if (cleaned.isEmpty) continue;
      items.add(AiStyleMemoryItem(id: id, text: cleaned));
    }
    return items;
  }

  static String encodeJson(List<AiStyleMemoryItem> items) {
    return jsonEncode([
      for (final item in items)
        if (normalizeItemText(item.text).isNotEmpty)
          {'id': item.id, 't': normalizeItemText(item.text)},
    ]);
  }
}
