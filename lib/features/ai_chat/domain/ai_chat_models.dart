import 'dart:convert';

import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../../search/domain/study_search_result.dart';

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

/// Kind of Study Vault content attached to a chat turn.
enum AiContextKind { lesson, material, note, studyPin }

extension AiContextKindX on AiContextKind {
  String get storageValue => switch (this) {
    AiContextKind.lesson => 'lesson',
    AiContextKind.material => 'material',
    AiContextKind.note => 'note',
    AiContextKind.studyPin => 'studyPin',
  };

  String get label => switch (this) {
    AiContextKind.lesson => 'Lesson',
    AiContextKind.material => 'Material',
    AiContextKind.note => 'Note',
    AiContextKind.studyPin => 'Pin',
  };

  static AiContextKind? fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'lesson' => AiContextKind.lesson,
      'material' => AiContextKind.material,
      'note' => AiContextKind.note,
      'studyPin' || 'pin' => AiContextKind.studyPin,
      _ => null,
    };
  }

  static AiContextKind? fromSearchKind(StudyEntityKind kind) {
    return switch (kind) {
      StudyEntityKind.lesson => AiContextKind.lesson,
      StudyEntityKind.material => AiContextKind.material,
      StudyEntityKind.note => AiContextKind.note,
      StudyEntityKind.studyPin => AiContextKind.studyPin,
      _ => null,
    };
  }
}

/// Attachment of Study Vault content to a chat turn.
class AiContextItem {
  const AiContextItem({
    required this.kind,
    required this.id,
    required this.title,
    this.lessonId,
    this.materialId,
    this.pageNumbers = const [],
    this.truncated = false,
    this.emptyReason,
    this.packedText,
  });

  final AiContextKind kind;
  final String id;
  final String title;
  final String? lessonId;
  final String? materialId;
  final List<int> pageNumbers;
  final bool truncated;
  final String? emptyReason;

  /// Extracted text packed once at send time (stored in contextJson).
  final String? packedText;

  String get chipLabel => '@$title';

  bool get hasUsableText =>
      packedText != null && packedText!.trim().isNotEmpty && emptyReason == null;

  AiContextItem copyWith({
    AiContextKind? kind,
    String? id,
    String? title,
    String? lessonId,
    String? materialId,
    List<int>? pageNumbers,
    bool? truncated,
    String? emptyReason,
    String? packedText,
    bool clearEmptyReason = false,
    bool clearPackedText = false,
  }) {
    return AiContextItem(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      title: title ?? this.title,
      lessonId: lessonId ?? this.lessonId,
      materialId: materialId ?? this.materialId,
      pageNumbers: pageNumbers ?? this.pageNumbers,
      truncated: truncated ?? this.truncated,
      emptyReason: clearEmptyReason ? null : (emptyReason ?? this.emptyReason),
      packedText: clearPackedText ? null : (packedText ?? this.packedText),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind.storageValue,
    'id': id,
    'title': title,
    if (lessonId != null) 'lessonId': lessonId,
    if (materialId != null) 'materialId': materialId,
    if (pageNumbers.isNotEmpty) 'pageNumbers': pageNumbers,
    'truncated': truncated,
    if (emptyReason != null) 'emptyReason': emptyReason,
    if (packedText != null) 'packedText': packedText,
  };

  /// Metadata-only JSON for draft chips (omit packed extract).
  Map<String, Object?> toDraftJson() => {
    'kind': kind.storageValue,
    'id': id,
    'title': title,
    if (lessonId != null) 'lessonId': lessonId,
    if (materialId != null) 'materialId': materialId,
  };

  factory AiContextItem.fromJson(Map<String, Object?> json) {
    final kind =
        AiContextKindX.fromStorage(json['kind'] as String?) ??
        AiContextKind.material;
    final pagesRaw = json['pageNumbers'];
    final pages = <int>[];
    if (pagesRaw is List) {
      for (final p in pagesRaw) {
        if (p is int) {
          pages.add(p);
        } else if (p is num) {
          pages.add(p.toInt());
        }
      }
    }
    return AiContextItem(
      kind: kind,
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Attachment',
      lessonId: json['lessonId'] as String?,
      materialId: json['materialId'] as String?,
      pageNumbers: pages,
      truncated: json['truncated'] == true,
      emptyReason: json['emptyReason'] as String?,
      packedText: json['packedText'] as String?,
    );
  }

  static String? encodeList(List<AiContextItem> items, {bool draft = false}) {
    if (items.isEmpty) return null;
    final encoded = jsonEncode([
      for (final i in items) draft ? i.toDraftJson() : i.toJson(),
    ]);
    return encoded;
  }

  static List<AiContextItem> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            AiContextItem.fromJson(Map<String, Object?>.from(item)),
      ];
    } on Object {
      return const [];
    }
  }

  /// Builds the model-facing block for one or more attachments.
  static String packForModel(List<AiContextItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('Attached Study Vault context:');
    for (final item in items) {
      buffer.writeln();
      buffer.writeln('### ${item.kind.label}: ${item.title}');
      if (item.emptyReason != null) {
        buffer.writeln('(${item.emptyReason})');
        continue;
      }
      final body = item.packedText?.trim() ?? '';
      if (body.isEmpty) {
        buffer.writeln('(No extractable text.)');
        continue;
      }
      buffer.writeln(body);
      if (item.truncated) {
        buffer.writeln();
        buffer.writeln('[Context truncated to fit size limits.]');
      }
    }
    return buffer.toString().trim();
  }

  /// Visible user text + packed attachments for the API turn.
  static String composeApiContent({
    required String userText,
    required List<AiContextItem> attachments,
  }) {
    final packed = packForModel(attachments);
    if (packed.isEmpty) return userText;
    return '$userText\n\n$packed';
  }
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
    required this.provider,
  });

  final String id;
  final String displayName;
  final String description;
  final bool recommended;

  /// Legacy intra-provider group (Recommended / Fast / Other).
  final String group;

  final AiProviderId provider;

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
      provider: AiProviderId.gemini,
    );
  }

  factory AiSelectableModel.fromDeepSeek(DeepSeekModelDefinition m) {
    return AiSelectableModel(
      id: m.id,
      displayName: m.displayName,
      description: m.description,
      recommended: m.recommended,
      group: m.recommended ? 'Recommended' : 'Other',
      provider: AiProviderId.deepseek,
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
