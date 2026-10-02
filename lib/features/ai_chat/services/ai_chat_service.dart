import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

/// Orchestrates local chat persistence + Gemini completions.
class AiChatService {
  AiChatService({
    required this.db,
    required this.gemini,
    required this.settings,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final GeminiChatService gemini;
  final AiSettingsStore settings;
  final Uuid _uuid;

  Stream<List<AiChat>> watchChats() => db.watchAiChats();

  Stream<AiChat?> watchChat(String id) => db.watchAiChatById(id);

  Stream<List<AiChatMessage>> watchMessages(String chatId) =>
      db.watchAiChatMessages(chatId);

  Future<AiChat> createChat({String? modelId}) async {
    final now = DateTime.now();
    final preferred = modelId ?? await settings.getModelId();
    final chat = AiChatsCompanion.insert(
      id: _uuid.v4(),
      title: 'New chat',
      modelId: GeminiModelRegistry.normalize(preferred),
      createdAt: now,
      updatedAt: now,
      lastMessageAt: Value(now),
    );
    await db.insertAiChat(chat);
    return (await db.getAiChatById(chat.id.value))!;
  }

  Future<void> renameChat(String chatId, String title) async {
    final chat = await db.getAiChatById(chatId);
    if (chat == null) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final clipped = trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
    await db.updateAiChat(
      chat.copyWith(title: clipped, updatedAt: DateTime.now()),
    );
  }

  Future<void> setChatModel(String chatId, String modelId) async {
    final chat = await db.getAiChatById(chatId);
    if (chat == null) return;
    await db.updateAiChat(
      chat.copyWith(
        modelId: GeminiModelRegistry.normalize(modelId),
        updatedAt: DateTime.now(),
      ),
    );
    await settings.setModelId(GeminiModelRegistry.normalize(modelId));
  }

  Future<void> saveDraft(String chatId, String? draft) async {
    final chat = await db.getAiChatById(chatId);
    if (chat == null) return;
    final value = draft?.trim();
    await db.updateAiChat(
      chat.copyWith(
        draftText: Value(value == null || value.isEmpty ? null : value),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteChat(String chatId) => db.deleteAiChat(chatId);

  Future<void> deleteAllChats() => db.deleteAllAiChats();

  /// Sends [userText], persists both sides, returns the assistant message.
  ///
  /// Uses non-stream complete so persistence stays simple; UI may call
  /// [streamSend] for progressive rendering.
  Future<AiChatMessage> sendMessage({
    required String chatId,
    required String userText,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      throw const AiServerException('Message is empty.');
    }

    var chat = await db.getAiChatById(chatId);
    if (chat == null) {
      throw const AiServerException('Chat not found.');
    }

    final now = DateTime.now();
    final userMessage = AiChatMessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      role: AiChatRole.user,
      content: text,
      status: const Value(AiChatMessageStatus.ok),
      createdAt: now,
    );
    await db.insertAiChatMessage(userMessage);

    final existing = await db.getAiChatMessages(chatId);
    final isFirstUser =
        existing.where((m) => m.role == AiChatRole.user).length == 1;
    if (isFirstUser || chat.title == 'New chat') {
      chat = chat.copyWith(title: generateChatTitle(text));
    }

    await db.updateAiChat(
      chat.copyWith(
        updatedAt: now,
        lastMessageAt: Value(now),
        draftText: const Value(null),
      ),
    );

    final history = existing
        .where((m) => m.status != AiChatMessageStatus.error)
        .map((m) => AiChatTurn(role: m.role, content: m.content))
        .toList();

    try {
      final completion = await gemini.complete(
        modelId: chat.modelId,
        history: history,
      );
      final assistantNow = DateTime.now();
      final assistant = AiChatMessagesCompanion.insert(
        id: _uuid.v4(),
        chatId: chatId,
        role: AiChatRole.assistant,
        content: completion.text,
        status: const Value(AiChatMessageStatus.ok),
        createdAt: assistantNow,
      );
      await db.insertAiChatMessage(assistant);
      final updatedChat = await db.getAiChatById(chatId);
      if (updatedChat != null) {
        await db.updateAiChat(
          updatedChat.copyWith(
            updatedAt: assistantNow,
            lastMessageAt: Value(assistantNow),
          ),
        );
      }
      return (await db.getAiChatMessages(chatId)).last;
    } on AiException catch (e) {
      final errNow = DateTime.now();
      await db.insertAiChatMessage(
        AiChatMessagesCompanion.insert(
          id: _uuid.v4(),
          chatId: chatId,
          role: AiChatRole.assistant,
          content: e.message,
          status: const Value(AiChatMessageStatus.error),
          createdAt: errNow,
        ),
      );
      rethrow;
    }
  }

  /// Streams the assistant reply into a temporary buffer; persists when done.
  ///
  /// Yields cumulative assistant text. Does not persist partial tokens.
  Stream<String> streamSend({
    required String chatId,
    required String userText,
  }) async* {
    final text = userText.trim();
    if (text.isEmpty) {
      throw const AiServerException('Message is empty.');
    }

    var chat = await db.getAiChatById(chatId);
    if (chat == null) {
      throw const AiServerException('Chat not found.');
    }

    final now = DateTime.now();
    await db.insertAiChatMessage(
      AiChatMessagesCompanion.insert(
        id: _uuid.v4(),
        chatId: chatId,
        role: AiChatRole.user,
        content: text,
        status: const Value(AiChatMessageStatus.ok),
        createdAt: now,
      ),
    );

    final existing = await db.getAiChatMessages(chatId);
    final isFirstUser =
        existing.where((m) => m.role == AiChatRole.user).length == 1;
    if (isFirstUser || chat.title == 'New chat') {
      chat = chat.copyWith(title: generateChatTitle(text));
    }
    await db.updateAiChat(
      chat.copyWith(
        updatedAt: now,
        lastMessageAt: Value(now),
        draftText: const Value(null),
      ),
    );

    final history = existing
        .where((m) => m.status != AiChatMessageStatus.error)
        .map((m) => AiChatTurn(role: m.role, content: m.content))
        .toList();

    final buffer = StringBuffer();
    try {
      await for (final delta in gemini.streamComplete(
        modelId: chat.modelId,
        history: history,
      )) {
        buffer.write(delta);
        yield buffer.toString();
      }
      final assistantNow = DateTime.now();
      await db.insertAiChatMessage(
        AiChatMessagesCompanion.insert(
          id: _uuid.v4(),
          chatId: chatId,
          role: AiChatRole.assistant,
          content: buffer.toString(),
          status: const Value(AiChatMessageStatus.ok),
          createdAt: assistantNow,
        ),
      );
      final updatedChat = await db.getAiChatById(chatId);
      if (updatedChat != null) {
        await db.updateAiChat(
          updatedChat.copyWith(
            updatedAt: assistantNow,
            lastMessageAt: Value(assistantNow),
          ),
        );
      }
    } on AiException catch (e) {
      await db.insertAiChatMessage(
        AiChatMessagesCompanion.insert(
          id: _uuid.v4(),
          chatId: chatId,
          role: AiChatRole.assistant,
          content: e.message,
          status: const Value(AiChatMessageStatus.error),
          createdAt: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  /// Retries after an error without duplicating the last user message.
  Future<AiChatMessage> retryLast({required String chatId}) async {
    final messages = await db.getAiChatMessages(chatId);
    if (messages.isEmpty) {
      throw const AiServerException('Nothing to retry.');
    }
    final last = messages.last;
    if (last.role == AiChatRole.assistant &&
        last.status == AiChatMessageStatus.error) {
      await db.deleteAiChatMessage(last.id);
    }
    final remaining = await db.getAiChatMessages(chatId);
    final lastUser = remaining.reversed
        .where((m) => m.role == AiChatRole.user)
        .firstOrNull;
    if (lastUser == null) {
      throw const AiServerException('Nothing to retry.');
    }

    // Remove the last user message then resend to avoid duplicates.
    await db.deleteAiChatMessage(lastUser.id);
    return sendMessage(chatId: chatId, userText: lastUser.content);
  }
}
