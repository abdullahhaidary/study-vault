import 'package:flutter_test/flutter_test.dart';
import 'helpers/ai_selection_helpers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/services/ai_output_validator.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/markdown_to_quill.dart';
import 'package:study_vault/features/ai_assistant/services/quill_to_markdown.dart';

void main() {
  group('GeminiApiKeys', () {
    test('splits pasted keys and masks suffixes', () {
      expect(GeminiApiKeys.split('  aaa  \nbbb,aaa;ccc  '), [
        'aaa',
        'bbb',
        'ccc',
      ]);
      expect(GeminiApiKeys.suffix('abcd1234xyz'), '4xyz');
      expect(GeminiApiKeys.parse('["one","two","one"]'), ['one', 'two']);
    });
  });

  group('MemoryAiCredentialStore', () {
    test('saves, replaces, and removes an API key', () async {
      final store = MemoryAiCredentialStore();

      expect(await store.hasApiKeyFor(AiProviderId.gemini), isFalse);
      await store.saveApiKeyFor(AiProviderId.gemini, ' first-key ');
      expect(await store.readApiKeyFor(AiProviderId.gemini), 'first-key');
      expect(await store.hasApiKeyFor(AiProviderId.gemini), isTrue);

      await store.replaceApiKeyFor(AiProviderId.gemini, 'second-key');
      expect(await store.readApiKeyFor(AiProviderId.gemini), 'second-key');
      await store.removeApiKeyFor(AiProviderId.gemini);
      expect(await store.hasApiKeyFor(AiProviderId.gemini), isFalse);
    });

    test('is an in-memory store, independent of Drift persistence', () async {
      final store = MemoryAiCredentialStore();
      await store.saveApiKeyFor(AiProviderId.gemini, 'temporary-key');
      expect(await store.readApiKeyFor(AiProviderId.gemini), 'temporary-key');
    });

    test('stores DeepSeek and Gemini keys independently', () async {
      final store = MemoryAiCredentialStore();
      await store.saveApiKeyFor(AiProviderId.gemini, 'g-key');
      await store.saveApiKeyFor(AiProviderId.deepseek, 'd-key');
      expect(await store.readApiKeyFor(AiProviderId.gemini), 'g-key');
      expect(await store.readApiKeyFor(AiProviderId.deepseek), 'd-key');
    });

    test('Gemini can store many keys and skip duplicates', () async {
      final store = MemoryAiCredentialStore();
      await store.addApiKeyFor(AiProviderId.gemini, 'key-one');
      await store.addApiKeyFor(
        AiProviderId.gemini,
        'key-two\nkey-one\nkey-three',
      );

      expect(await store.readApiKeysFor(AiProviderId.gemini), [
        'key-one',
        'key-two',
        'key-three',
      ]);
      expect(await store.readApiKeyFor(AiProviderId.gemini), 'key-one');
      expect(await store.readApiKeySuffixesFor(AiProviderId.gemini), [
        '-one',
        '-two',
        'hree',
      ]);

      await store.removeApiKeyAt(AiProviderId.gemini, 1);
      expect(await store.readApiKeysFor(AiProviderId.gemini), [
        'key-one',
        'key-three',
      ]);
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
        AiStudyRequest(
          selection: testGeminiSelection(),
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
        AiStudyRequest(
          selection: testGeminiSelection(),
          action: AiStudyAction.explain,
          sourceText: source,
        ),
      );
      final organize = await service.run(
        AiStudyRequest(
          selection: testGeminiSelection(),
          action: AiStudyAction.organize,
          sourceText: source,
        ),
      );
      final flashcards = await service.run(
        AiStudyRequest(
          selection: testGeminiSelection(),
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

  test('MarkdownToQuill renders tables as labelled bullets', () {
    const md =
        '| Dimension | Target |\n|---|---|\n| Delivery | Go-live |\n| Quality | 0 defects |';
    final document = MarkdownToQuill.toDocument(md);
    final plain = document.toPlainText();
    expect(plain, contains('Delivery — Go-live'));
    expect(plain, contains('Quality — 0 defects'));
    expect(plain, isNot(contains('|')));
    expect(MarkdownToQuill.looksLikeMarkdown(md), isTrue);
  });

  test('QuillToMarkdown round-trips headings, lists, code, charts, links', () {
    const md =
        '# Title\n\n'
        'Intro with **bold**, *italic*, `code` and a [link](https://x.y).\n\n'
        '## Section\n\n'
        '- One\n- Two\n  - Nested\n\n'
        '1. First\n2. Second\n\n'
        '> A quote\n\n'
        '```chart\n'
        '{"type":"bar","labels":["a","b"],"series":[{"name":"s","data":[1,2]}]}\n'
        '```\n\n'
        '---\n\n'
        'Last paragraph.';
    final once = QuillToMarkdown.fromStored(MarkdownToQuill.toDeltaJson(md));
    expect(once, md);
    // Stable on a second pass.
    final twice = QuillToMarkdown.fromStored(MarkdownToQuill.toDeltaJson(once));
    expect(twice, once);
  });

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
