import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/gemini_model_registry.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';

void main() {
  group('GeminiModelRegistry', () {
    test('default model is gemini-3.8-flash', () {
      expect(GeminiModelRegistry.defaultModelId, 'gemini-3.8-flash');
      expect(
        GeminiModelRegistry.normalize(null),
        GeminiModelRegistry.defaultModelId,
      );
    });

    test('excludes deprecated and non-chat models', () {
      expect(GeminiModelRegistry.isExcluded('gemini-2.0-flash'), isTrue);
      expect(GeminiModelRegistry.isExcluded('text-embedding-004'), isTrue);
      expect(GeminiModelRegistry.isExcluded('imagen-3.0'), isTrue);
      expect(GeminiModelRegistry.isExcluded('gemini-3.8-flash'), isFalse);
    });

    test('fallback list is primary models only', () {
      final ids = GeminiModelRegistry.fallbackChatModels()
          .map((m) => m.id)
          .toSet();
      expect(ids, contains('gemini-3.8-flash'));
      expect(ids, contains('gemini-3.5-flash'));
      expect(ids, contains('gemini-3.5-flash-lite'));
      expect(ids, isNot(contains('gemini-2.0-flash')));
      expect(ids, isNot(contains('gemini-2.5-pro')));
    });

    test('resolveAvailable adds optional models when listed by API', () {
      final models = GeminiModelRegistry.resolveAvailable(
        serverModelIds: {
          'models/gemini-3.8-flash',
          'models/gemini-3.7-flash',
          'models/gemini-2.5-flash',
          'models/text-embedding-004',
        },
      );
      final ids = models.map((m) => m.id).toSet();
      expect(ids, contains('gemini-3.8-flash'));
      expect(ids, contains('gemini-3.7-flash'));
      expect(ids, contains('gemini-2.5-flash'));
      expect(ids, isNot(contains('text-embedding-004')));
    });
  });

  group('generateChatTitle', () {
    test('uses first message and truncates', () {
      expect(generateChatTitle('Hello world'), 'Hello world');
      final long = List.filled(20, 'word').join(' ');
      final title = generateChatTitle(long);
      expect(title.length, lessThanOrEqualTo(57));
      expect(title, endsWith('…'));
    });
  });

  group('AiChatService persistence', () {
    late AppDatabase db;
    late MemoryAiCredentialStore credentials;
    late MemoryAiSettingsStore settings;
    late FakeGeminiChatService gemini;
    late AiChatService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.gemini, 'test-key');
      settings = MemoryAiSettingsStore();
      await settings.setPrivacyConsentAccepted(true);
      await settings.setModelId(GeminiModelRegistry.defaultModelId);
      gemini = FakeGeminiChatService(
        credentials: credentials,
        settings: settings,
        reply: 'Assistant answer about gradients.',
      );
      service = AiChatService(db: db, gemini: gemini, settings: settings);
    });

    tearDown(() async {
      await db.close();
    });

    test('schema version is 16', () {
      expect(db.schemaVersion, 16);
    });

    test('create chat, send message, persist history and continue', () async {
      final chat = await service.createChat();
      expect(chat.modelId, 'gemini-3.8-flash');

      await service.sendMessage(
        chatId: chat.id,
        userText: 'Explain gradient descent',
      );

      final messages = await db.getAiChatMessages(chat.id);
      expect(messages.length, 2);
      expect(messages.first.role, AiChatRole.user);
      expect(messages.first.content, 'Explain gradient descent');
      expect(messages.last.role, AiChatRole.assistant);
      expect(messages.last.content, contains('gradients'));
      expect(messages.last.totalTokens, 120);
      expect(messages.last.promptTokens, 80);
      expect(messages.last.completionTokens, 40);
      expect(messages.last.aiProvider, 'gemini');

      final updated = await db.getAiChatById(chat.id);
      expect(updated!.title, 'Explain gradient descent');

      await service.sendMessage(chatId: chat.id, userText: 'Give an example');
      expect(gemini.sentHistories.last.length, 3);
      expect(
        gemini.sentHistories.last.first.content,
        'Explain gradient descent',
      );
      expect(gemini.sentHistories.last.last.content, 'Give an example');

      final all = await db.getAiChatMessages(chat.id);
      expect(all.length, 4);
    });

    test('delete chat removes messages', () async {
      final chat = await service.createChat();
      await service.sendMessage(chatId: chat.id, userText: 'Hi');
      await service.deleteChat(chat.id);
      expect(await db.getAiChatById(chat.id), isNull);
      expect(await db.getAiChatMessages(chat.id), isEmpty);
    });

    test('rename and change model keep history', () async {
      final chat = await service.createChat();
      await service.sendMessage(chatId: chat.id, userText: 'Topic A');
      await service.renameChat(chat.id, 'My revision');
      await service.setChatModel(chat.id, 'gemini-3.5-flash-lite');

      final updated = await db.getAiChatById(chat.id);
      expect(updated!.title, 'My revision');
      expect(updated.modelId, 'gemini-3.5-flash-lite');
      expect(await db.getAiChatMessages(chat.id), hasLength(2));
      expect(await settings.getModelId(), 'gemini-3.5-flash-lite');
    });

    test('setChatModel to DeepSeek switches default provider', () async {
      final chat = await service.createChat();
      await service.setChatModel(chat.id, 'deepseek-flash');

      expect(await settings.getProvider(), AiProviderId.deepseek);
      expect(await settings.getModelId(), 'deepseek-flash');
      expect((await db.getAiChatById(chat.id))!.modelId, 'deepseek-flash');
    });

    test(
      'retry removes error message and does not duplicate user turn',
      () async {
        gemini = FakeGeminiChatService(
          credentials: credentials,
          settings: settings,
          failWith: const AiServerException('boom'),
        );
        service = AiChatService(db: db, gemini: gemini, settings: settings);
        final chat = await service.createChat();
        try {
          await service.sendMessage(chatId: chat.id, userText: 'Retry me');
          fail('expected error');
        } on AiServerException {
          // expected
        }
        var messages = await db.getAiChatMessages(chat.id);
        expect(messages.last.status, AiChatMessageStatus.error);

        gemini = FakeGeminiChatService(
          credentials: credentials,
          settings: settings,
          reply: 'Recovered',
        );
        service = AiChatService(db: db, gemini: gemini, settings: settings);
        await service.retryLast(chatId: chat.id);
        messages = await db.getAiChatMessages(chat.id);
        expect(messages.where((m) => m.role == AiChatRole.user), hasLength(1));
        expect(messages.last.content, 'Recovered');
        expect(messages.last.status, AiChatMessageStatus.ok);
      },
    );

    test('regenerate replaces the successful assistant response', () async {
      final chat = await service.createChat();
      await service.sendMessage(chatId: chat.id, userText: 'Explain hashing');

      gemini = FakeGeminiChatService(
        credentials: credentials,
        settings: settings,
        reply: 'A different explanation',
      );
      service = AiChatService(db: db, gemini: gemini, settings: settings);
      await service.retryLast(chatId: chat.id);

      final messages = await db.getAiChatMessages(chat.id);
      expect(messages, hasLength(2));
      expect(messages.first.content, 'Explain hashing');
      expect(messages.last.content, 'A different explanation');
    });

    test('edit and resend removes the later conversation branch', () async {
      final chat = await service.createChat();
      await service.sendMessage(chatId: chat.id, userText: 'Original question');
      await service.sendMessage(chatId: chat.id, userText: 'Old follow-up');
      final original = (await db.getAiChatMessages(chat.id)).first;

      gemini = FakeGeminiChatService(
        credentials: credentials,
        settings: settings,
        reply: 'Answer to edited question',
      );
      service = AiChatService(db: db, gemini: gemini, settings: settings);
      await service.editAndResend(
        chatId: chat.id,
        messageId: original.id,
        userText: 'Edited question',
      );

      final messages = await db.getAiChatMessages(chat.id);
      expect(messages, hasLength(2));
      expect(messages.first.content, 'Edited question');
      expect(messages.last.content, 'Answer to edited question');
      expect(
        messages.any((message) => message.content == 'Old follow-up'),
        isFalse,
      );
    });
  });
}
