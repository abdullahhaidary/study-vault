import 'ai_provider.dart';

/// Central source of truth for DeepSeek model IDs.
///
/// Persist [DeepSeekModelDefinition.id] only — never display names.
abstract final class DeepSeekModelRegistry {
  static const defaultModelId = flash;

  /// Current official limits for the selectable V4 text models.
  static const contextWindowTokens = 1000000;
  static const maximumOutputTokens = 393216;

  /// Fast default for inline study actions.
  static const flash = 'deepseek-flash';

  /// Stronger reasoning for harder / structured tasks.
  static const v4Pro = 'deepseek-v4-pro';

  /// Alias accepted from older docs / API listings → [flash].
  static const _legacyFlashAlias = 'deepseek-v4-flash';

  static const List<DeepSeekModelDefinition> all = [
    DeepSeekModelDefinition(
      id: flash,
      displayName: 'DeepSeek Flash',
      description:
          'Fast default for explain, simplify, define, translate, and inline asks.',
      recommended: true,
      supportsVision: true,
      supportsThinking: true,
      defaultThinking: AiThinkingMode.low,
    ),
    DeepSeekModelDefinition(
      id: v4Pro,
      displayName: 'DeepSeek V4 Pro',
      description:
          'Stronger reasoning for detailed explanations, large quizzes, '
          'and difficult structured study tasks.',
      recommended: false,
      supportsVision: false,
      supportsThinking: true,
      defaultThinking: AiThinkingMode.high,
    ),
  ];

  static final Map<String, DeepSeekModelDefinition> _byId = {
    for (final m in all) m.id: m,
  };

  static DeepSeekModelDefinition? byId(String id) {
    final normalized = normalize(id);
    return _byId[normalized];
  }

  static bool isKnown(String id) {
    final lower = id.trim().toLowerCase();
    return _byId.containsKey(lower) || lower == _legacyFlashAlias;
  }

  static String displayName(String id) =>
      byId(id)?.displayName ?? 'DeepSeek model';

  static String normalize(String? id) {
    final raw = id?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return defaultModelId;
    if (raw == _legacyFlashAlias) return flash;
    if (_byId.containsKey(raw)) return raw;
    return defaultModelId;
  }

  static List<DeepSeekModelDefinition> selectableModels() =>
      List.unmodifiable(all);

  /// Simple Auto routing: prefer Pro for heavy structured work, else Flash.
  static String resolveAuto({required bool preferPro}) =>
      preferPro ? v4Pro : flash;
}

class DeepSeekModelDefinition {
  const DeepSeekModelDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.recommended,
    required this.supportsVision,
    required this.supportsThinking,
    required this.defaultThinking,
  });

  final String id;
  final String displayName;
  final String description;
  final bool recommended;
  final bool supportsVision;
  final bool supportsThinking;
  final AiThinkingMode defaultThinking;
}

/// Sentinel model id meaning "route automatically" (settings only).
abstract final class DeepSeekModelIds {
  static const auto = 'auto';

  static bool isAuto(String? id) =>
      id == null || id.trim().isEmpty || id.trim().toLowerCase() == auto;
}
