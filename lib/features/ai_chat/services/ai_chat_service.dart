import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../domain/ai_chat_models.dart';
import 'chat_context_resolver.dart';
import 'gemini_chat_service.dart';

/// Orchestrates local chat persistence + provider completions.
class AiChatService {
  AiChatService({
    required this.db,
    required this.settings,
    AiChatTransport? transport,

    /// Backward-compatible alias for older call sites / tests.
    AiChatTransport? gemini,
    ChatContextResolver? contextResolver,
    Uuid? uuid,
  }) : transport = transport ?? gemini!,
       contextResolver = contextResolver ?? ChatContextResolver(db: db),
       _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final AiChatTransport transport;
  final AiSettingsStore settings;
  final ChatContextResolver contextResolver;
  final Uuid _uuid;

  static const maxAttachmentsPerMessage = 4;

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
      modelId: _normalizeModel(preferred, await settings.getProvider()),
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
    final provider = AiProviderIdX.fromModelId(modelId);
    final normalized = _normalizeModel(modelId, provider);
    await db.updateAiChat(
      chat.copyWith(modelId: normalized, updatedAt: DateTime.now()),
    );
    await settings.setProvider(provider);
    await settings.setModelIdFor(provider, normalized);
  }

  String _normalizeModel(String modelId, AiProviderId provider) {
    return switch (provider) {
      AiProviderId.gemini => GeminiModelRegistry.normalize(modelId),
      AiProviderId.deepseek =>
        DeepSeekModelIds.isAuto(modelId)
            ? DeepSeekModelRegistry.defaultModelId
            : DeepSeekModelRegistry.normalize(modelId),
    };
  }

  Future<void> saveDraft(
    String chatId,
    String? draft, {
    List<AiContextItem>? draftAttachments,
  }) async {
    final chat = await db.getAiChatById(chatId);
    if (chat == null) return;
    final value = draft?.trim();
    final contextJson = draftAttachments == null
        ? chat.draftContextJson
        : AiContextItem.encodeList(draftAttachments, draft: true);
    await db.updateAiChat(
      chat.copyWith(
        draftText: Value(value == null || value.isEmpty ? null : value),
        draftContextJson: Value(contextJson),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteChat(String chatId) => db.deleteAiChat(chatId);

  Future<void> deleteAllChats() => db.deleteAllAiChats();

  List<AiChatTurn> _historyTurns(List<AiChatMessage> messages) {
    return [
      for (final m in messages)
        if (m.status != AiChatMessageStatus.error)
          AiChatTurn(
            role: m.role,
            content: _apiContentForMessage(m),
          ),
    ];
  }

  String _apiContentForMessage(AiChatMessage message) {
    if (message.role != AiChatRole.user) return message.content;
    final attachments = AiContextItem.decodeList(message.contextJson);
    if (attachments.isEmpty) return message.content;
    return AiContextItem.composeApiContent(
      userText: message.content,
      attachments: attachments,
    );
  }

  Future<List<AiContextItem>> _resolveAttachments(
    List<AiContextItem> attachments,
  ) async {
    if (attachments.isEmpty) return const [];
    final clipped = attachments.length > maxAttachmentsPerMessage
        ? attachments.sublist(0, maxAttachmentsPerMessage)
        : attachments;
    return contextResolver.resolveAll(clipped);
  }

  /// Sends [userText], persists both sides, returns the assistant message.
  ///
  /// Uses non-stream complete so persistence stays simple; UI may call
  /// [streamSend] for progressive rendering.
  Future<AiChatMessage> sendMessage({
    required String chatId,
    required String userText,
    List<AiContextItem> attachments = const [],
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      throw const AiServerException('Message is empty.');
    }

    var chat = await db.getAiChatById(chatId);
    if (chat == null) {
      throw const AiServerException('Chat not found.');
    }

    final resolved = await _resolveAttachments(attachments);
    final now = DateTime.now();
    final userMessage = AiChatMessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      role: AiChatRole.user,
      content: text,
      status: const Value(AiChatMessageStatus.ok),
      contextJson: Value(AiContextItem.encodeList(resolved)),
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
        draftContextJson: const Value(null),
      ),
    );

    final history = _historyTurns(existing);

    try {
      final completion = await transport.complete(
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
    List<AiContextItem> attachments = const [],
  }) async* {
    final text = userText.trim();
    if (text.isEmpty) {
      throw const AiServerException('Message is empty.');
    }

    var chat = await db.getAiChatById(chatId);
    if (chat == null) {
      throw const AiServerException('Chat not found.');
    }

    final resolved = await _resolveAttachments(attachments);
    final now = DateTime.now();
    await db.insertAiChatMessage(
      AiChatMessagesCompanion.insert(
        id: _uuid.v4(),
        chatId: chatId,
        role: AiChatRole.user,
        content: text,
        status: const Value(AiChatMessageStatus.ok),
        contextJson: Value(AiContextItem.encodeList(resolved)),
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
        draftContextJson: const Value(null),
      ),
    );

    final history = _historyTurns(existing);

    final buffer = StringBuffer();
    try {
      await for (final delta in transport.streamComplete(
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

    final attachments = AiContextItem.decodeList(lastUser.contextJson);
    // Remove the last user message then resend to avoid duplicates.
    await db.deleteAiChatMessage(lastUser.id);
    return sendMessage(
      chatId: chatId,
      userText: lastUser.content,
      attachments: [
        for (final a in attachments)
          a.copyWith(clearPackedText: true, clearEmptyReason: true),
      ],
    );
  }
}
