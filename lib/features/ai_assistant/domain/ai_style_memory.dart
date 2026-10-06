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

/// Library-wide style history prepended to AI system prompts (not one chat).
///
/// Each note is long-form (about 10–20 sentences). Gemini, DeepSeek, and Claude
/// reuse a stable prefix, so this block is cheaper after the first request.
abstract final class AiStyleMemory {
  /// Paid in full on a cache miss. Keep notes under this when you edit often.
  static const uncachedTokenBudget = 1000;

  /// Allowed when the provider caches the system prefix (typical here).
  static const cachedTokenBudget = 2000;

  /// Enough for about 10–20 sentences, not a single keyword.
  static const maxItemChars = 3500;
  static const header = 'STYLE:';
  static const noteSeparator = '\n\n---\n\n';

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

  /// Trims edges but keeps sentence and paragraph breaks.
  static String normalizeItemText(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return '';
    final lines = [
      for (final line in normalized.split('\n'))
        line.trim().replaceAll(RegExp(r'[ \t]+'), ' '),
    ];
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String? compact(List<AiStyleMemoryItem> items) {
    final notes = [
      for (final item in items) normalizeItemText(item.text),
    ].where((note) => note.isNotEmpty).toList();
    if (notes.isEmpty) return null;
    return '$header\n${notes.join(noteSeparator)}';
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
      final body = text.substring(header.length).trim();
      if (body.isEmpty) return const [];
      if (body.contains('\n---\n')) {
        final notes = <AiStyleMemoryItem>[];
        for (final part in body.split(RegExp(r'\n---\n'))) {
          final cleaned = normalizeItemText(part);
          if (cleaned.isEmpty || cleaned == '---') continue;
          notes.add(
            AiStyleMemoryItem(id: 'm${notes.length + 1}', text: cleaned),
          );
        }
        if (notes.isNotEmpty) return notes;
      }
      final bulletLines = body.split('\n');
      final looksLikeBullets = bulletLines.every(
        (line) =>
            line.trim().isEmpty ||
            line.trimLeft().startsWith('- ') ||
            line.trimLeft().startsWith('* '),
      );
      if (looksLikeBullets) {
        final bullets = <AiStyleMemoryItem>[];
        for (final line in bulletLines) {
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
      return [AiStyleMemoryItem(id: 'legacy', text: normalizeItemText(body))];
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
