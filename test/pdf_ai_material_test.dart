import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'helpers/ai_selection_helpers.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_token_usage.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';

void main() {
  group('PDF AI prompt structure', () {
    test('all five generation types have distinct typed instructions', () {
      final instructions = {
        for (final type in PdfAiMaterialType.values)
          type.storageValue: type.generationInstruction,
      };

      expect(instructions, hasLength(5));
      expect(instructions['slideshow'], contains('<!-- slide -->'));
      expect(instructions['summary'], contains('concise'));
      expect(instructions['explanation'], contains('university student'));
      expect(instructions['deep_explanation'], contains('first principles'));
      expect(instructions['real_world_examples'], contains('## Topic map'));
      expect(instructions['real_world_examples'], contains('**Scenario**'));
      expect(
        instructions['real_world_examples'],
        contains('do not re-teach the theory'),
      );
      expect(
        PdfAiMaterialTypeX.fromStorage('real_world_examples'),
        PdfAiMaterialType.realWorldExamples,
      );
      expect(
        PdfAiMaterialType.summary.maxOutputTokens,
        lessThan(PdfAiMaterialType.explanation.maxOutputTokens),
      );
      expect(
        PdfAiMaterialType.explanation.maxOutputTokens,
        lessThan(PdfAiMaterialType.deepExplanation.maxOutputTokens),
      );
    });

    test('slideshow splits slides and accepts heading-only fallbacks', () {
      expect(
        PdfAiSlideDeck.parse(
          '# Slide 1: Start\nIntro\n<!-- slide -->\n# Slide 2: Finish\nDone',
        ),
        ['# Slide 1: Start\nIntro', '# Slide 2: Finish\nDone'],
      );
      expect(
        PdfAiSlideDeck.parse(
          '# Slide 1: Start\nIntro\n# Slide 2: Finish\nDone',
        ),
        ['# Slide 1: Start\nIntro', '# Slide 2: Finish\nDone'],
      );
    });

    test('system and stable document prefixes are identical across modes', () {
      const document = 'DOCUMENT: Test\n\n--- Page 1 ---\nContent';
      final prompts = [
        for (final type in PdfAiMaterialType.values)
          PdfAiPromptBuilder.messages(stableDocument: document, type: type),
      ];

      for (final prompt in prompts.skip(1)) {
        expect(prompt[0], prompts.first[0]);
        expect(prompt[1], prompts.first[1]);
      }
      expect(
        prompts.map((prompt) => prompt[2]['content']).toSet(),
        hasLength(PdfAiMaterialType.values.length),
      );
      final custom = PdfAiPromptBuilder.messages(
        stableDocument: document,
        type: PdfAiMaterialType.summary,
        customInstruction: 'Focus on formulas.',
      );
      expect(custom[0], prompts.first[0]);
      expect(custom[1], prompts.first[1]);
      expect(custom[2]['content'], endsWith('Focus on formulas.'));
    });

    test(
      'document representation is ordered, deterministic, and fingerprinted',
      () {
        final first = PdfDocumentRepresentation.build(
          title: 'Lecture',
          pages: const [
            SourcePageText(pageNumber: 2, text: 'Second'),
            SourcePageText(pageNumber: 1, text: 'First'),
          ],
        );
        final same = PdfDocumentRepresentation.build(
          title: 'Lecture',
          pages: const [
            SourcePageText(pageNumber: 1, text: 'First'),
            SourcePageText(pageNumber: 2, text: 'Second'),
          ],
        );
        final changed = PdfDocumentRepresentation.build(
          title: 'Lecture',
          pages: const [
            SourcePageText(pageNumber: 1, text: 'Changed'),
            SourcePageText(pageNumber: 2, text: 'Second'),
          ],
        );

        expect(first.stableDocument, same.stableDocument);
        expect(first.sourceFingerprint, same.sourceFingerprint);
        expect(first.sourceFingerprint, isNot(changed.sourceFingerprint));
        expect(
          first.stableDocument.indexOf('Page 1'),
          lessThan(first.stableDocument.indexOf('Page 2')),
        );
      },
    );
  });

  group('PDF AI material persistence', () {
    late AppDatabase db;
    late _FakeTextSource source;
    late _FakeCompletionClient client;
    late PdfAiMaterialService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedMaterial(db);
      source = _FakeTextSource([
        const SourcePageText(pageNumber: 1, text: 'Alpha'),
        const SourcePageText(pageNumber: 2, text: 'Beta'),
      ]);
      client = _FakeCompletionClient();
      service = PdfAiMaterialService(db, client, textSource: source);
    });

    tearDown(() => db.close());

    test('regeneration preserves versions and newest loads first', () async {
      client.outputs.addAll(['Version one', 'Version two']);
      final first = await _generate(service);
      final second = await _generate(service);
      final history = await service.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );

      expect(first.version, 1);
      expect(second.version, 2);
      expect(history.map((item) => item.version), [2, 1]);
      expect(history.map((item) => item.content), [
        'Version two',
        'Version one',
      ]);
    });

    test(
      'manual edits persist as new versions without an AI request',
      () async {
        for (final type in PdfAiMaterialType.values) {
          client.outputs.add('Original ${type.name}');
          final original = await _generate(service, type: type);
          final callsBeforeEdit = client.messages.length;
          final edited = await service.editVersion(
            original: original,
            content: '  Corrected ${type.name}  ',
          );
          final history = await service.history(
            materialId: 'pdf-1',
            type: type,
          );

          expect(edited.version, 2);
          expect(history.map((item) => item.content), [
            'Corrected ${type.name}',
            'Original ${type.name}',
          ]);
          expect(client.messages, hasLength(callsBeforeEdit));
          expect(edited.provider, isNull);
        }
      },
    );

    test('usage and cache metrics persist with every version', () async {
      client.outputs.add('Summary');
      client.usage = const AiTokenUsage(
        promptTokens: 100,
        completionTokens: 20,
        totalTokens: 120,
        cacheHitTokens: 80,
        cacheMissTokens: 20,
      );

      final saved = await _generate(service);

      expect(saved.provider, 'deepseek');
      expect(saved.model, 'deepseek-flash');
      expect(saved.promptTokens, 100);
      expect(saved.completionTokens, 20);
      expect(saved.totalTokens, 120);
      expect(saved.cacheHitTokens, 80);
      expect(saved.cacheMissTokens, 20);
    });

    test('missing usage still saves a completed generation', () async {
      client.outputs.add('No usage response');
      client.usage = null;

      final saved = await _generate(service);

      expect(saved.content, 'No usage response');
      expect(saved.promptTokens, isNull);
      expect(saved.totalTokens, isNull);
      expect(saved.provider, 'deepseek');
      expect(saved.model, 'deepseek-flash');
    });

    test('changed extracted content is detectable by fingerprint', () async {
      client.outputs.add('First');
      final saved = await _generate(service);
      source.pages = [
        const SourcePageText(pageNumber: 1, text: 'Changed source'),
      ];

      final currentFingerprint = await service.sourceFingerprint(
        title: 'PDF',
        filePath: '/fake.pdf',
      );

      expect(saved.sourceFingerprint, isNot(currentFingerprint));
    });

    test('failed regeneration leaves previous version current', () async {
      client.outputs.add('Good version');
      await _generate(service);
      client.failure = const AiServerException('failed');

      await expectLater(_generate(service), throwsA(isA<AiServerException>()));
      final history = await service.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );

      expect(history, hasLength(1));
      expect(history.single.version, 1);
      expect(history.single.content, 'Good version');
    });

    test('duplicate taps cannot start the same generation twice', () async {
      client.outputs.add('Only response');
      client.gate = Completer<void>();
      final first = _generate(service);
      while (client.messages.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      await expectLater(_generate(service), throwsA(isA<StateError>()));
      client.gate!.complete();
      await first;

      final history = await service.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );
      expect(history, hasLength(1));
    });

    test('deleting one version keeps the PDF and other versions', () async {
      client.outputs.addAll(['One', 'Two']);
      final first = await _generate(service);
      await _generate(service);

      await service.deleteVersion(first.id);

      expect(await db.getMaterialById('pdf-1'), isNotNull);
      final history = await service.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );
      expect(history, hasLength(1));
      expect(history.single.version, 2);
    });

    test('deleting the source PDF cascades its generated materials', () async {
      client.outputs.add('One');
      await _generate(service);

      await db.deleteLessonMaterial('pdf-1');

      final history = await service.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );
      expect(history, isEmpty);
    });

    test(
      'large documents use every chunk and aggregate request usage',
      () async {
        final largeText = List.filled(270000, 'x').join();
        source.pages = [SourcePageText(pageNumber: 1, text: largeText)];
        client.dynamicDigestMode = true;
        client.usage = const AiTokenUsage(
          promptTokens: 10,
          completionTokens: 2,
          totalTokens: 12,
          cacheHitTokens: 4,
          cacheMissTokens: 6,
        );

        final saved = await _generate(service);
        final chunkCalls = client.messages.where(
          (messages) =>
              messages.last['content']!.startsWith('This is source segment'),
        );
        final finalDocument = client.messages.last[1]['content']!;

        expect(chunkCalls.length, greaterThan(1));
        for (var i = 1; i <= chunkCalls.length; i++) {
          expect(finalDocument, contains('DIGEST-$i'));
        }
        expect(saved.promptTokens, 10 * client.messages.length);
        expect(saved.completionTokens, 2 * client.messages.length);
        expect(saved.totalTokens, 12 * client.messages.length);
        expect(saved.cacheHitTokens, 4 * client.messages.length);
        expect(saved.cacheMissTokens, 6 * client.messages.length);
      },
    );
  });
}

Future<PdfAiMaterial> _generate(
  PdfAiMaterialService service, {
  PdfAiMaterialType type = PdfAiMaterialType.summary,
}) {
  return service.generate(
    materialId: 'pdf-1',
    title: 'PDF',
    filePath: '/fake.pdf',
    type: type,
    selection: testDeepSeekSelection(),
  );
}

Future<void> _seedMaterial(AppDatabase db) async {
  final now = DateTime(2026);
  await db.insertClass(
    ClassesCompanion.insert(
      id: 'class-1',
      name: 'Class',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertSubject(
    SubjectsCompanion.insert(
      id: 'subject-1',
      classId: 'class-1',
      name: 'Subject',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLesson(
    LessonsCompanion.insert(
      id: 'lesson-1',
      subjectId: 'subject-1',
      name: 'Lesson',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLessonMaterial(
    LessonMaterialsCompanion.insert(
      id: 'pdf-1',
      lessonId: 'lesson-1',
      title: 'PDF',
      originalFileName: 'pdf.pdf',
      storedFileName: 'pdf.pdf',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

class _FakeTextSource implements PdfDocumentTextSource {
  _FakeTextSource(this.pages);

  List<SourcePageText> pages;

  @override
  Future<List<SourcePageText>> extractAllPages(String filePath) async => pages;
}

class _FakeCompletionClient implements PdfAiCompletionClient {
  final List<String> outputs = [];
  final List<List<Map<String, String>>> messages = [];
  AiTokenUsage? usage = const AiTokenUsage(
    promptTokens: 10,
    completionTokens: 2,
    totalTokens: 12,
    cacheHitTokens: 4,
    cacheMissTokens: 6,
  );
  Object? failure;
  bool dynamicDigestMode = false;
  Completer<void>? gate;
  int _digestCount = 0;

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) async {
    this.messages.add(messages);
    final error = failure;
    if (error != null) throw error;
    await gate?.future;
    final isDigest = messages.last['content']!.startsWith(
      'This is source segment',
    );
    final output = dynamicDigestMode
        ? isDigest
              ? 'DIGEST-${++_digestCount}'
              : 'FINAL'
        : outputs.removeAt(0);
    return PdfAiCompletion(
      markdown: output,
      provider: 'deepseek',
      model: 'deepseek-flash',
      usage: usage,
    );
  }
}
