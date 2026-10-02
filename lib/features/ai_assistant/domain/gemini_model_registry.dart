/// Central source of truth for Gemini text-chat / study model IDs.
///
/// Persist [GeminiModelDefinition.id] only — never display names.
abstract final class GeminiModelRegistry {
  static const defaultModelId = 'gemini-3.8-flash';

  static const List<GeminiModelDefinition> all = [
    GeminiModelDefinition(
      id: 'gemini-3.8-flash',
      displayName: 'Gemini 3.8 Flash',
      description:
          'Best overall choice for Study Vault — reasoning, coding, and long context.',
      tier: GeminiModelTier.recommended,
      recommended: true,
      supportsThinkingLevel: true,
      showByDefault: true,
    ),
    GeminiModelDefinition(
      id: 'gemini-3.5-flash',
      displayName: 'Gemini 3.5 Flash',
      description: 'Strong general-purpose production model.',
      tier: GeminiModelTier.standard,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: true,
    ),
    GeminiModelDefinition(
      id: 'gemini-3.5-flash-lite',
      displayName: 'Gemini 3.5 Flash-Lite',
      description: 'Faster and lower cost for simpler conversations.',
      tier: GeminiModelTier.fast,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: true,
    ),
    GeminiModelDefinition(
      id: 'gemini-3.7-flash',
      displayName: 'Gemini 3.7 Flash',
      description: 'Optional Flash model when available on your API account.',
      tier: GeminiModelTier.optional,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: false,
    ),
    GeminiModelDefinition(
      id: 'gemini-3.6-flash',
      displayName: 'Gemini 3.6 Flash',
      description: 'Optional Flash model when available on your API account.',
      tier: GeminiModelTier.optional,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: false,
    ),
    GeminiModelDefinition(
      id: 'gemini-2.5-pro',
      displayName: 'Gemini 2.5 Pro',
      description: 'Compatibility model — not recommended for new chats.',
      tier: GeminiModelTier.compatibility,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: false,
    ),
    GeminiModelDefinition(
      id: 'gemini-2.5-flash',
      displayName: 'Gemini 2.5 Flash',
      description: 'Compatibility model for accounts that still use 2.5 Flash.',
      tier: GeminiModelTier.compatibility,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: false,
    ),
    GeminiModelDefinition(
      id: 'gemini-2.5-flash-lite',
      displayName: 'Gemini 2.5 Flash-Lite',
      description: 'Compatibility lite model.',
      tier: GeminiModelTier.compatibility,
      recommended: false,
      supportsThinkingLevel: false,
      showByDefault: false,
    ),
  ];

  /// Explicitly excluded (deprecated / shutdown / non-text-chat).
  static const excludedIds = {
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  };

  static final Map<String, GeminiModelDefinition> _byId = {
    for (final m in all) m.id: m,
  };

  static GeminiModelDefinition? byId(String id) => _byId[id];

  static bool isKnown(String id) => _byId.containsKey(id);

  static bool isExcluded(String id) {
    final lower = id.toLowerCase();
    if (excludedIds.contains(lower)) return true;
    if (lower.contains('embedding')) return true;
    if (lower.contains('imagen')) return true;
    if (lower.contains('veo')) return true;
    if (lower.contains('tts')) return true;
    if (lower.contains('live')) return true;
    if (lower.contains('robot')) return true;
    return false;
  }

  static String displayName(String id) =>
      byId(id)?.displayName ?? 'Previous model unavailable';

  static String normalize(String? id) {
    if (id != null && isKnown(id)) return id;
    return defaultModelId;
  }

  /// Models shown when API listing is unavailable.
  static List<GeminiModelDefinition> fallbackChatModels() {
    return all.where((m) => m.showByDefault).toList(growable: false);
  }

  /// Intersect server-available model names with the app allowlist.
  ///
  /// Primary models always appear. Optional / compatibility models appear
  /// only when the API lists them.
  static List<GeminiModelDefinition> resolveAvailable({
    required Set<String> serverModelIds,
  }) {
    if (serverModelIds.isEmpty) return fallbackChatModels();

    final normalizedServer = <String>{};
    for (final raw in serverModelIds) {
      final id = raw.contains('/') ? raw.split('/').last : raw;
      if (!isExcluded(id)) normalizedServer.add(id);
    }

    final out = <GeminiModelDefinition>[];
    for (final m in all) {
      if (m.showByDefault || normalizedServer.contains(m.id)) {
        out.add(m);
      }
    }
    return out.isEmpty ? fallbackChatModels() : List.unmodifiable(out);
  }
}

enum GeminiModelTier { recommended, standard, fast, optional, compatibility }

class GeminiModelDefinition {
  const GeminiModelDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.tier,
    required this.recommended,
    required this.supportsThinkingLevel,
    required this.showByDefault,
  });

  final String id;
  final String displayName;
  final String description;
  final GeminiModelTier tier;
  final bool recommended;
  final bool supportsThinkingLevel;
  final bool showByDefault;
}
