import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';

/// Message roles persisted in [AiChatMessages.role].
abstract final class AiChatRole {
  static const user = 'user';
  static const assistant = 'assistant';
  static const system = 'system';
}

/// Message status persisted in [AiChatMessages.status].
abstract final class AiChatMessageStatus {
  static const ok = 'ok';
  static const error = 'error';
}

/// Future attachment of Study Vault content to a chat turn.
class AiContextItem {
  const AiContextItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.textContent,
  });

  final String entityType;
  final String entityId;
  final String title;
  final String? textContent;
}

/// One turn sent to the chat transport (already persisted or in-flight).
class AiChatTurn {
  const AiChatTurn({required this.role, required this.content});

  final String role;
  final String content;
}

/// Result of a completed (non-stream) chat completion.
class AiChatCompletion {
  const AiChatCompletion({required this.text, this.modelId});

  final String text;
  final String? modelId;
}

/// Provider-agnostic model row for chat model pickers.
class AiSelectableModel {
  const AiSelectableModel({
    required this.id,
    required this.displayName,
    required this.description,
    required this.recommended,
    required this.group,
  });

  final String id;
  final String displayName;
  final String description;
  final bool recommended;

  /// UI group: Recommended / Fast / Other.
  final String group;

  factory AiSelectableModel.fromGemini(GeminiModelDefinition m) {
    final group = switch (m.tier) {
      GeminiModelTier.recommended => 'Recommended',
      GeminiModelTier.fast => 'Fast',
      _ => m.recommended ? 'Recommended' : 'Other',
    };
    return AiSelectableModel(
      id: m.id,
      displayName: m.displayName,
      description: m.description,
      recommended: m.recommended,
      group: group,
    );
  }

  factory AiSelectableModel.fromDeepSeek(DeepSeekModelDefinition m) {
    return AiSelectableModel(
      id: m.id,
      displayName: m.displayName,
      description: m.description,
      recommended: m.recommended,
      group: m.recommended ? 'Recommended' : 'Other',
    );
  }
}

/// Builds a short deterministic title from the first user message.
String generateChatTitle(String firstUserMessage, {int maxLength = 56}) {
  final collapsed = firstUserMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'New chat';
  if (collapsed.length <= maxLength) return collapsed;
  final cut = collapsed.substring(0, maxLength).trimRight();
  final lastSpace = cut.lastIndexOf(' ');
  if (lastSpace > maxLength ~/ 2) {
    return '${cut.substring(0, lastSpace)}…';
  }
  return '$cut…';
}
