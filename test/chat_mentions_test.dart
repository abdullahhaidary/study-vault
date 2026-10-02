import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/gemini_model_registry.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/chat_context_resolver.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/search/data/study_search_service.dart';
import 'package:study_vault/features/search/domain/study_search_result.dart';

void main() {
  group('AiContextItem', () {
    test('encode/decode round-trip keeps packedText', () {
      final items = [
        const AiContextItem(
          kind: AiContextKind.material,
          id: 'm1',
          title: 'Slides',
          lessonId: 'l1',
          materialId: 'm1',
          pageNumbers: [1, 2],
          truncated: true,
          packedText: '--- Page 1 ---\nHello',
        ),
      ];
      final raw = AiContextItem.encodeList(items);
      final decoded = AiContextItem.decodeList(raw);
      expect(decoded, hasLength(1));
      expect(decoded.first.kind, AiContextKind.material);
      expect(decoded.first.packedText, '--- Page 1 ---\nHello');
      expect(decoded.first.truncated, isTrue);
      expect(decoded.first.pageNumbers, [1, 2]);
    });

    test('draft encode omits packedText', () {
      final items = [
        const AiContextItem(
          kind: AiContextKind.note,
          id: 'n1',
          title: 'My note',
          packedText: 'secret body',
        ),
      ];
      final draft = AiContextItem.decodeList(
        AiContextItem.encodeList(items, draft: true),
      );
      expect(draft.first.packedText, isNull);
      expect(draft.first.title, 'My note');
    });

    test('composeApiContent appends packed block', () {
      final out = AiContextItem.composeApiContent(
        userText: 'Summarize this',
        attachments: [
          const AiContextItem(
            kind: AiContextKind.material,
            id: 'm1',
            title: 'Deck',
            packedText: '--- Page 1 ---\nGradient descent',
          ),
        ],
      );
      expect(out, contains('Summarize this'));
      expect(out, contains('Attached Study Vault context:'));
      expect(out, contains('Gradient descent'));
    });
  });

  group('ChatContextResolver', () {
    late AppDatabase db;
    late ChatContextResolver resolver;
    late Directory tempDir;
    late String emptyPdfPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('chat_mentions_');
      emptyPdfPath = p.join(tempDir.path, 'empty.pdf');
      await File(p.join(tempDir.path, 'slides.pdf')).writeAsBytes(const [0]);
      await File(emptyPdfPath).writeAsBytes(const [0]);

      db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime(2026, 4, 1);
      await db.insertClass(
        ClassesCompanion.insert(
          id: 'c1',
          name: 'Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's1',
          classId: 'c1',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l1',
          subjectId: 's1',
          name: 'Lesson One',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'mat-pdf',
          lessonId: 'l1',
          title: 'Midterm slides',
          originalFileName: 'slides.pdf',
          storedFileName: 'slides.pdf',
          mimeType: const Value('application/pdf'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'mat-img',
          lessonId: 'l1',
          title: 'Photo slide',
          originalFileName: 'photo.jpg',
          storedFileName: 'photo.jpg',
          mimeType: const Value('image/jpeg'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertStudyNote(
        StudyNotesCompanion.insert(
          id: 'note-1',
          title: 'Revision note',
          content: '[{"insert":"Key definitions\\n"}]',
          plainTextContent: const Value('Key definitions'),
          lessonId: const Value('l1'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'pin-1',
          resourceId: 'mat-pdf',
          pinType: const Value('point'),
          pageNumber: const Value(3),
          xRatio: 0.2,
          yRatio: 0.3,
          shortText: 'GD formula',
          fullExplanationPlainText: const Value('Gradient = nabla J'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      resolver = ChatContextResolver(
        db: db,
        maxCharsPerAttachment: 100,
        maxCharsCombined: 150,
        resolveMaterialPath:
            ({
              required String lessonId,
              required String storedFileName,
            }) async => p.join(tempDir.path, storedFileName),
        extractPages:
            ({required String filePath, Set<int>? pageNumbers}) async {
              if (filePath.endsWith('empty.pdf')) {
                return const [];
              }
              return const [
                SourcePageText(
                  pageNumber: 1,
                  text: 'Page one content about ML',
                ),
                SourcePageText(
                  pageNumber: 2,
                  text:
                      'Page two content about GD that is fairly long for tests',
                ),
              ];
            },
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('draftFromSearch maps material hit', () {
      final item = resolver.draftFromSearch(
        const StudySearchResult(
          kind: StudyEntityKind.material,
          id: 'mat-pdf',
          title: 'Midterm slides',
          breadcrumb: 'Class › Subject',
          lessonId: 'l1',
          materialId: 'mat-pdf',
        ),
      );
      expect(item.kind, AiContextKind.material);
      expect(item.id, 'mat-pdf');
      expect(item.packedText, isNull);
    });

    test('resolves PDF material with page markers', () async {
      final item = await resolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.material,
          id: 'mat-pdf',
          title: 'Midterm slides',
        ),
      );
      expect(item.emptyReason, isNull);
      expect(item.packedText, contains('--- Page 1 ---'));
      expect(item.packedText, contains('Page one content'));
      expect(item.pageNumbers, [1, 2]);
    });

    test('image material reports no extractable text', () async {
      final item = await resolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.material,
          id: 'mat-img',
          title: 'Photo slide',
        ),
      );
      expect(item.emptyReason, 'No extractable text in this file.');
      expect(item.packedText, isNull);
    });

    test('empty PDF extract sets emptyReason', () async {
      final emptyResolver = ChatContextResolver(
        db: db,
        resolveMaterialPath:
            ({
              required String lessonId,
              required String storedFileName,
            }) async => emptyPdfPath,
        extractPages:
            ({required String filePath, Set<int>? pageNumbers}) async =>
                const [],
      );
      final item = await emptyResolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.material,
          id: 'mat-pdf',
          title: 'Midterm slides',
        ),
      );
      expect(item.emptyReason, 'No text in this file.');
    });

    test('lesson concatenates materials and respects caps', () async {
      final item = await resolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.lesson,
          id: 'l1',
          title: 'Lesson One',
        ),
      );
      expect(item.kind, AiContextKind.lesson);
      expect(item.packedText, contains('Midterm slides'));
      expect(item.truncated || (item.packedText?.length ?? 0) <= 100, isTrue);
    });

    test('note and pin resolve plain text', () async {
      final note = await resolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.note,
          id: 'note-1',
          title: 'Revision note',
        ),
      );
      expect(note.packedText, 'Key definitions');

      final pin = await resolver.resolveOne(
        const AiContextItem(
          kind: AiContextKind.studyPin,
          id: 'pin-1',
          title: 'GD formula',
        ),
      );
      expect(pin.packedText, contains('GD formula'));
      expect(pin.packedText, contains('Gradient = nabla J'));
      expect(pin.pageNumbers, [3]);
    });

    test('combined budget truncates later attachments', () async {
      final resolved = await resolver.resolveAll([
        const AiContextItem(
          kind: AiContextKind.material,
          id: 'mat-pdf',
          title: 'Midterm slides',
        ),
        const AiContextItem(
          kind: AiContextKind.note,
          id: 'note-1',
          title: 'Revision note',
        ),
      ]);
      expect(resolved, hasLength(2));
      expect(resolved.first.packedText, isNotNull);
      expect(
        resolved.last.truncated ||
            resolved.last.emptyReason != null ||
            (resolved.last.packedText?.length ?? 0) <= 150,
        isTrue,
      );
    });
  });

  group('AiChatService attachments', () {
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
        reply: 'Summary ready.',
      );

      final now = DateTime(2026, 4, 1);
      await db.insertClass(
        ClassesCompanion.insert(
          id: 'c1',
          name: 'Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's1',
          classId: 'c1',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l1',
          subjectId: 's1',
          name: 'Lesson One',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertStudyNote(
        StudyNotesCompanion.insert(
          id: 'note-1',
          title: 'Revision note',
          content: 'plain',
          plainTextContent: const Value('Key definitions about ML'),
          lessonId: const Value('l1'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      service = AiChatService(
        db: db,
        gemini: gemini,
        settings: settings,
        contextResolver: ChatContextResolver(db: db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'send with attachment persists contextJson and packs API history',
      () async {
        final chat = await service.createChat();
        await service.sendMessage(
          chatId: chat.id,
          userText: 'Summarize this note',
          attachments: [
            const AiContextItem(
              kind: AiContextKind.note,
              id: 'note-1',
              title: 'Revision note',
            ),
          ],
        );

        final messages = await db.getAiChatMessages(chat.id);
        final user = messages.firstWhere((m) => m.role == AiChatRole.user);
        expect(user.content, 'Summarize this note');
        final attachments = AiContextItem.decodeList(user.contextJson);
        expect(attachments, hasLength(1));
        expect(attachments.first.packedText, contains('Key definitions'));

        expect(gemini.sentHistories, isNotEmpty);
        final apiUser = gemini.sentHistories.last.firstWhere(
          (t) => t.role == AiChatRole.user,
        );
        expect(apiUser.content, contains('Summarize this note'));
        expect(apiUser.content, contains('Key definitions about ML'));
        expect(apiUser.content, isNot(equals(user.content)));
      },
    );

    test('saveDraft stores draftContextJson chips', () async {
      final chat = await service.createChat();
      await service.saveDraft(
        chat.id,
        'hello',
        draftAttachments: [
          const AiContextItem(
            kind: AiContextKind.note,
            id: 'note-1',
            title: 'Revision note',
            packedText: 'should not persist in draft',
          ),
        ],
      );
      final updated = await db.getAiChatById(chat.id);
      expect(updated!.draftText, 'hello');
      final chips = AiContextItem.decodeList(updated.draftContextJson);
      expect(chips, hasLength(1));
      expect(chips.first.id, 'note-1');
      expect(chips.first.packedText, isNull);
    });
  });

  group('StudySearchService mentions', () {
    late AppDatabase db;
    late StudySearchService search;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      search = StudySearchService(db);
      final now = DateTime(2026, 4, 1);
      await db.insertClass(
        ClassesCompanion.insert(
          id: 'c1',
          name: 'Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's1',
          classId: 'c1',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l1',
          subjectId: 's1',
          name: 'Photosynthesis',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('suggestMentions returns recent lessons', () async {
      final hits = await search.suggestMentions();
      expect(hits.any((h) => h.kind == StudyEntityKind.lesson), isTrue);
      expect(hits.any((h) => h.title == 'Photosynthesis'), isTrue);
    });

    test('searchForMentions filters by query', () async {
      final hits = await search.searchForMentions('Photo');
      expect(hits.any((h) => h.id == 'l1'), isTrue);
    });
  });
}
