import '../../../core/database/app_database.dart';
import 'ai_chat_models.dart';

/// One sent user message that referenced a study item via contextJson.
class ReferencedAiMessage {
  const ReferencedAiMessage({
    required this.chatId,
    required this.messageId,
    required this.chatTitle,
    required this.userMessage,
    required this.createdAt,
    this.assistantReplyPreview,
  });

  final String chatId;
  final String messageId;
  final String chatTitle;
  final String userMessage;
  final DateTime createdAt;

  /// Optional short preview of the next assistant turn (1–2 lines).
  final String? assistantReplyPreview;
}

/// Messages grouped under one chat for reverse-reference UI.
class ReferencedAiChatGroup {
  const ReferencedAiChatGroup({
    required this.chatId,
    required this.chatTitle,
    required this.messages,
    this.lastActivityAt,
  });

  final String chatId;
  final String chatTitle;
  final List<ReferencedAiMessage> messages;
  final DateTime? lastActivityAt;

  int get messageCount => messages.length;
}

/// Builds reverse AI-chat lookups from the normalized context-ref index.
class ReferencedAiMessageRepository {
  ReferencedAiMessageRepository({required this.db});

  final AppDatabase db;

  static const previewMaxChars = 140;

  Stream<int> watchCount({required AiContextKind kind, required String id}) {
    return db.watchAiMessageContextRefCount(
      contextType: kind.storageValue,
      contextId: id,
    );
  }

  Future<int> count({required AiContextKind kind, required String id}) {
    return db.countAiMessageContextRefs(
      contextType: kind.storageValue,
      contextId: id,
    );
  }

  Stream<List<ReferencedAiMessage>> watchMessages({
    required AiContextKind kind,
    required String id,
  }) {
    return db
        .watchAiMessagesReferencing(
          contextType: kind.storageValue,
          contextId: id,
        )
        .asyncMap((messages) => _enrich(messages));
  }

  Future<List<ReferencedAiMessage>> getMessages({
    required AiContextKind kind,
    required String id,
  }) async {
    final messages = await db.getAiMessagesReferencing(
      contextType: kind.storageValue,
      contextId: id,
    );
    return _enrich(messages);
  }

  Future<List<ReferencedAiChatGroup>> getGrouped({
    required AiContextKind kind,
    required String id,
  }) async {
    final items = await getMessages(kind: kind, id: id);
    return groupByChat(items);
  }

  Stream<List<ReferencedAiChatGroup>> watchGrouped({
    required AiContextKind kind,
    required String id,
  }) {
    return watchMessages(kind: kind, id: id).map(groupByChat);
  }

  /// Groups messages by chat; chats ordered by most recent activity,
  /// messages within a chat chronological.
  static List<ReferencedAiChatGroup> groupByChat(
    List<ReferencedAiMessage> items,
  ) {
    if (items.isEmpty) return const [];

    final order = <String>[];
    final byChat = <String, List<ReferencedAiMessage>>{};
    final titles = <String, String>{};
    final activity = <String, DateTime?>{};

    for (final item in items) {
      if (!byChat.containsKey(item.chatId)) {
        order.add(item.chatId);
        byChat[item.chatId] = [];
        titles[item.chatId] = item.chatTitle;
        activity[item.chatId] = item.createdAt;
      }
      byChat[item.chatId]!.add(item);
      final prev = activity[item.chatId];
      if (prev == null || item.createdAt.isAfter(prev)) {
        activity[item.chatId] = item.createdAt;
      }
    }

    return [
      for (final chatId in order)
        ReferencedAiChatGroup(
          chatId: chatId,
          chatTitle: titles[chatId] ?? 'Study AI',
          messages: List.unmodifiable(byChat[chatId]!),
          lastActivityAt: activity[chatId],
        ),
    ];
  }

  Future<List<ReferencedAiMessage>> _enrich(
    List<AiChatMessage> messages,
  ) async {
    if (messages.isEmpty) return const [];

    final chatIds = {for (final m in messages) m.chatId};
    final chats = <String, AiChat>{};
    for (final chatId in chatIds) {
      final chat = await db.getAiChatById(chatId);
      if (chat != null) chats[chatId] = chat;
    }

    final result = <ReferencedAiMessage>[];
    for (final message in messages) {
      final chat = chats[message.chatId];
      final reply = await _nextAssistantPreview(
        chatId: message.chatId,
        after: message.createdAt,
      );
      result.add(
        ReferencedAiMessage(
          chatId: message.chatId,
          messageId: message.id,
          chatTitle: chat?.title ?? 'Study AI',
          userMessage: message.content,
          createdAt: message.createdAt,
          assistantReplyPreview: reply,
        ),
      );
    }
    return result;
  }

  Future<String?> _nextAssistantPreview({
    required String chatId,
    required DateTime after,
  }) async {
    final all = await db.getAiChatMessages(chatId);
    for (final m in all) {
      if (m.role != AiChatRole.assistant) continue;
      if (m.createdAt.isBefore(after)) continue;
      if (m.status == AiChatMessageStatus.error) continue;
      final text = m.content.trim();
      if (text.isEmpty) return null;
      if (text.length <= previewMaxChars) return text;
      return '${text.substring(0, previewMaxChars).trimRight()}…';
    }
    return null;
  }
}
