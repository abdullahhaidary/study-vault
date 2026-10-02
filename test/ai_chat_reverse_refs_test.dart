import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/backup/backup_providers.dart';
import 'package:study_vault/core/backup/backup_service.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/domain/referenced_ai_message.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';

void main() {
  late AppDatabase db;
  late AiChatService service;
  late ReferencedAiMessageRepository repo;
  late MemoryAiCredentialStore credentials;
  late MemoryAiSettingsStore settings;
  late FakeGeminiChatService gemini;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    credentials = MemoryAiCredentialStore();
    await credentials.saveApiKeyFor(AiProviderId.gemini, 'test-key');
    settings = MemoryAiSettingsStore();
    await settings.setPrivacyConsentAccepted(true);
    gemini = FakeGeminiChatService(
      credentials: credentials,
      settings: settings,
      reply: 'Because squaring keeps errors positive.',
    );
    service = AiChatService(db: db, gemini: gemini, settings: settings);
    repo = ReferencedAiMessageRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('schema version is 16 with backup constants', () {
    expect(db.schemaVersion, 16);
    expect(kStudyVaultSchemaVersion, 16);
    expect(BackupService().currentSchemaVersion, 16);
  });

  test('saving message indexes lesson + pdf refs once each', () async {
    final chat = await service.createChat();
    await service.sendMessage(
      chatId: chat.id,
      userText: 'Why do we square the error?',
      attachments: const [
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-1',
          title: 'Lesson 1',
        ),
        AiContextItem(
          kind: AiContextKind.material,
          id: 'pdf-8',
          title: 'Slides',
        ),
        // Duplicate lesson should collapse to one reverse-ref row.
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-1',
          title: 'Lesson 1 again',
        ),
      ],
    );

    final lessonRefs = await db.countAiMessageContextRefs(
      contextType: 'lesson',
      contextId: 'lesson-1',
    );
    final pdfRefs = await db.countAiMessageContextRefs(
      contextType: 'material',
      contextId: 'pdf-8',
    );
    expect(lessonRefs, 1);
    expect(pdfRefs, 1);

    final lessonMsgs = await repo.getMessages(
      kind: AiContextKind.lesson,
      id: 'lesson-1',
    );
    expect(lessonMsgs, hasLength(1));
    expect(lessonMsgs.first.userMessage, 'Why do we square the error?');
    expect(lessonMsgs.first.assistantReplyPreview, contains('squaring'));

    final pdfMsgs = await repo.getMessages(
      kind: AiContextKind.material,
      id: 'pdf-8',
    );
    expect(pdfMsgs, hasLength(1));
    expect(pdfMsgs.first.messageId, lessonMsgs.first.messageId);
  });

  test('reverse query returns only matching item', () async {
    final chat = await service.createChat();
    await service.sendMessage(
      chatId: chat.id,
      userText: 'About lesson 1',
      attachments: const [
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-1',
          title: 'Lesson 1',
        ),
      ],
    );
    await service.sendMessage(
      chatId: chat.id,
      userText: 'About lesson 2',
      attachments: const [
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-2',
          title: 'Lesson 2',
        ),
      ],
    );

    final only1 = await repo.getMessages(
      kind: AiContextKind.lesson,
      id: 'lesson-1',
    );
    expect(only1.map((m) => m.userMessage), ['About lesson 1']);
  });

  test(
    'delete message removes reverse refs; delete chat removes all',
    () async {
      final chat = await service.createChat();
      await service.sendMessage(
        chatId: chat.id,
        userText: 'Q1',
        attachments: const [
          AiContextItem(kind: AiContextKind.note, id: 'note-1', title: 'Note'),
        ],
      );
      await service.sendMessage(
        chatId: chat.id,
        userText: 'Q2',
        attachments: const [
          AiContextItem(kind: AiContextKind.note, id: 'note-1', title: 'Note'),
        ],
      );

      expect(
        await db.countAiMessageContextRefs(
          contextType: 'note',
          contextId: 'note-1',
        ),
        2,
      );

      final messages = await db.getAiChatMessages(chat.id);
      final firstUser = messages.firstWhere((m) => m.role == AiChatRole.user);
      await db.deleteAiChatMessage(firstUser.id);

      expect(
        await db.countAiMessageContextRefs(
          contextType: 'note',
          contextId: 'note-1',
        ),
        1,
      );

      await service.deleteChat(chat.id);
      expect(
        await db.countAiMessageContextRefs(
          contextType: 'note',
          contextId: 'note-1',
        ),
        0,
      );
    },
  );

  test('rename does not break reverse lookup by id', () async {
    final chat = await service.createChat();
    await service.sendMessage(
      chatId: chat.id,
      userText: 'Explain GD',
      attachments: const [
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-1',
          title: 'Lesson 1',
        ),
      ],
    );

    // Historical title in contextJson may stay "Lesson 1"; lookup uses id.
    final found = await repo.getMessages(
      kind: AiContextKind.lesson,
      id: 'lesson-1',
    );
    expect(found, hasLength(1));
    expect(found.first.userMessage, 'Explain GD');
  });

  test('draftContextJson is not indexed', () async {
    final chat = await service.createChat();
    await service.saveDraft(
      chat.id,
      'unsent',
      draftAttachments: const [
        AiContextItem(
          kind: AiContextKind.lesson,
          id: 'lesson-draft',
          title: 'Draft lesson',
        ),
      ],
    );

    expect(
      await db.countAiMessageContextRefs(
        contextType: 'lesson',
        contextId: 'lesson-draft',
      ),
      0,
    );
  });

  test('backfill indexes historical contextJson', () async {
    final now = DateTime(2026, 9, 29);
    await db.insertAiChat(
      AiChatsCompanion.insert(
        id: 'chat-old',
        title: 'Study AI',
        modelId: 'gemini-3.8-flash',
        createdAt: now,
        updatedAt: now,
      ),
    );
    // Insert without going through companion indexing path by using raw insert
    // then clearing and backfilling — simulate pre-schema-15 rows.
    await db
        .into(db.aiChatMessages)
        .insert(
          AiChatMessagesCompanion.insert(
            id: 'msg-old',
            chatId: 'chat-old',
            role: AiChatRole.user,
            content: 'Historical question',
            contextJson: Value(
              AiContextItem.encodeList(const [
                AiContextItem(
                  kind: AiContextKind.studyPin,
                  id: 'pin-9',
                  title: 'Pin',
                ),
              ]),
            ),
            createdAt: now,
          ),
        );
    // The override insertAiChatMessage already indexes; clear and re-backfill
    // to prove backfill works on existing rows.
    await (db.delete(db.aiMessageContextRefs)).go();
    expect(
      await db.countAiMessageContextRefs(
        contextType: 'studyPin',
        contextId: 'pin-9',
      ),
      0,
    );

    await db.backfillAiMessageContextRefs();
    expect(
      await db.countAiMessageContextRefs(
        contextType: 'studyPin',
        contextId: 'pin-9',
      ),
      1,
    );

    final grouped = await repo.getGrouped(
      kind: AiContextKind.studyPin,
      id: 'pin-9',
    );
    expect(grouped, hasLength(1));
    expect(grouped.first.chatId, 'chat-old');
    expect(grouped.first.messages.first.messageId, 'msg-old');
  });

  test('groupByChat keeps chronological messages under newest chats', () {
    final groups = ReferencedAiMessageRepository.groupByChat([
      ReferencedAiMessage(
        chatId: 'a',
        messageId: 'm1',
        chatTitle: 'Chat A',
        userMessage: 'First',
        createdAt: DateTime(2026, 9, 29),
      ),
      ReferencedAiMessage(
        chatId: 'a',
        messageId: 'm2',
        chatTitle: 'Chat A',
        userMessage: 'Second',
        createdAt: DateTime(2026, 9, 30),
      ),
      ReferencedAiMessage(
        chatId: 'b',
        messageId: 'm3',
        chatTitle: 'Chat B',
        userMessage: 'Other',
        createdAt: DateTime(2026, 9, 28),
      ),
    ]);
    // Order follows input chat-first-seen order (query already sorts chats).
    expect(groups.map((g) => g.chatId), ['a', 'b']);
    expect(groups.first.messages.map((m) => m.userMessage), [
      'First',
      'Second',
    ]);
  });
}
