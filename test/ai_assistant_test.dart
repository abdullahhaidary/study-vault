import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/services/ai_output_validator.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/markdown_to_quill.dart';

void main() {
  group('MemoryAiCredentialStore', () {
    test('saves, replaces, and removes an API key', () async {
      final store = MemoryAiCredentialStore();

      expect(await store.hasApiKey, isFalse);
      await store.saveApiKey(' first-key ');
      expect(await store.readApiKey(), 'first-key');
      expect(await store.hasApiKey, isTrue);

      await store.replaceApiKey('second-key');
      expect(await store.readApiKey(), 'second-key');
      await store.removeApiKey();
      expect(await store.hasApiKey, isFalse);
    });

    test('is an in-memory store, independent of Drift persistence', () async {
      final store = MemoryAiCredentialStore();
      await store.saveApiKey('temporary-key');
      expect(await store.readApiKey(), 'temporary-key');
    });
  });

  group('AiOutputValidator', () {
    test('parses a valid annotation and maps its category', () {
      final annotation = AiOutputValidator.parseAnnotation(
        '{"shortDescription":"Gradient","fullNote":"A derivative",'
        '"suggestedCategory":"Definition"}',
        categoryNameToId: const {'Definition': 'definition-id'},
      );

      expect(annotation.shortDescription, 'Gradient');
      expect(annotation.suggestedCategory, 'definition-id');
    });

    test('rejects an invalid annotation', () {
      expect(
        () => AiOutputValidator.parseAnnotation(
          '{"fullNote":"Missing short description"}',
          categoryNameToId: const {},
        ),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });

    test('parses valid flashcards and rejects invalid ones', () {
      final result = AiOutputValidator.parseFlashcards(
        '{"cards":[{"front":"What is a gradient?","back":"A derivative."}]}',
      );
      expect(result.cards, hasLength(1));

      expect(
        () => AiOutputValidator.parseFlashcards('{"cards":[{"front":""}]}'),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });

    test('uses no category for an unknown annotation category', () {
      final annotation = AiOutputValidator.parseAnnotation(
        '{"shortDescription":"Term","fullNote":"Definition",'
        '"suggestedCategory":"Unknown"}',
        categoryNameToId: const {'Definition': 'definition-id'},
      );
      expect(annotation.suggestedCategory, isNull);
    });
  });

  test(
    'AiPromptBuilder preserves meaning and honors language instructions',
    () {
      final prompt = AiPromptBuilder.rephraseText(
        const AiStudyRequest(
          action: AiStudyAction.rephrase,
          sourceText: 'Gradient Descent updates θ.',
          language: AiLanguage.persianDari,
          rephraseMode: AiRephraseMode.preserveMeaning,
        ),
      );

      expect(prompt, contains('Preserve-meaning rules'));
      expect(prompt, contains('Persian/Dari'));
      expect(prompt, contains('strictly preserving meaning'));
    },
  );

  test(
    'FakeAiService returns deterministic explain, organize, and flashcards',
    () async {
      final service = FakeAiService();
      const source = 'Gradient descent reduces cost.';

      final explain = await service.run(
        const AiStudyRequest(action: AiStudyAction.explain, sourceText: source),
      );
      final organize = await service.run(
        const AiStudyRequest(
          action: AiStudyAction.organize,
          sourceText: source,
        ),
      );
      final flashcards = await service.run(
        const AiStudyRequest(
          action: AiStudyAction.generateFlashcards,
          sourceText: source,
          flashcardCount: 2,
        ),
      );

      expect(explain, isA<AiTextResult>());
      expect(organize, isA<AiTextResult>());
      expect(flashcards, isA<AiFlashcardsResult>());
      expect((flashcards as AiFlashcardsResult).cards, hasLength(2));
    },
  );

  test(
    'MarkdownToQuill creates a non-empty delta from headings and bullets',
    () {
      final document = MarkdownToQuill.toDocument(
        '# Heading\n\n- One\n- Two\n\n**Bold** and *italic*',
      );
      expect(document.toDelta().toJson(), isNotEmpty);
      expect(document.toPlainText(), contains('Heading'));
      expect(document.toPlainText(), contains('One'));
      expect(document.toPlainText(), isNot(contains('#')));
      expect(document.toPlainText(), isNot(contains('- One')));
      expect(document.toPlainText(), isNot(contains('**')));

      final ops = document.toDelta().toJson() as List<dynamic>;
      final hasHeader = ops.any(
        (op) =>
            op is Map &&
            op['attributes'] is Map &&
            (op['attributes'] as Map)['header'] == 1,
      );
      final hasBullet = ops.any(
        (op) =>
            op is Map &&
            op['attributes'] is Map &&
            (op['attributes'] as Map)['list'] == 'bullet',
      );
      final hasBold = ops.any(
        (op) =>
            op is Map &&
            op['attributes'] is Map &&
            (op['attributes'] as Map)['bold'] == true,
      );
      expect(hasHeader, isTrue);
      expect(hasBullet, isTrue);
      expect(hasBold, isTrue);
    },
  );

  test('MarkdownToQuill treats -- and --- as horizontal rules', () {
    final document = MarkdownToQuill.toDocument(
      'Above\n\n--\n\nMiddle\n\n---\n\nBelow',
    );
    final ops = document.toDelta().toJson() as List<dynamic>;
    final dividers = ops.where(
      (op) =>
          op is Map && op['insert'] is Map && op['insert']['divider'] != null,
    );
    expect(dividers.length, 2);
    expect(document.toPlainText(), isNot(contains('--')));
  });
}
