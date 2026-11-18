import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_endpoint_profile_repository.dart';
import 'package:study_vault/features/ai_assistant/data/ai_model_catalog_providers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_providers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_endpoint_profile.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_pdf_document.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_selectable_model.dart';
import 'package:study_vault/features/ai_assistant/services/deepseek_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/gemini_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/new_api_claude_service.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';
import 'package:study_vault/features/pdf_ai_materials/data/pdf_ai_material_providers.dart';
import 'package:study_vault/features/reference_books/data/book_repository.dart';
import 'package:study_vault/features/reference_books/domain/book_ai_input.dart';
import 'package:study_vault/features/reference_books/domain/book_chapter_detector.dart';
import 'package:study_vault/features/reference_books/domain/book_text_index.dart';
import 'package:study_vault/features/reference_books/presentation/book_ai_request_picker.dart';
import 'package:study_vault/features/reference_books/services/book_ai_service.dart';
import 'package:study_vault/features/reference_books/services/book_pdf_source.dart';
import 'package:study_vault/features/reference_books/services/book_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BookRepository repository;
  late MemoryAiCredentialStore credentials;
  late MemoryAiSettingsStore settings;
  late MemoryAiEndpointCatalogStore metadata;
  late AiEndpointProfileRepository profiles;
  late Directory directory;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BookRepository(db);
    credentials = MemoryAiCredentialStore();
    settings = MemoryAiSettingsStore();
    await settings.setPrivacyConsentAccepted(true);
    metadata = MemoryAiEndpointCatalogStore();
    profiles = AiEndpointProfileRepository(
      store: metadata,
      settings: settings,
      credentials: credentials,
    );
    directory = await Directory.systemTemp.createTemp('sv-book-provider-test-');
  });
  tearDown(() async {
    profiles.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  AiExecutionSelection selection(AiProviderId provider, {String? profileId}) =>
      AiExecutionSelection.fromStored(
        provider: provider,
        modelId: provider == AiProviderId.gemini
            ? 'gemini-3.8-flash'
            : provider == AiProviderId.deepseek
            ? 'deepseek-flash'
            : 'claude-book',
        endpointProfileId: profileId,
      );
  Future<AiEndpointProfile> profile({
    bool pdf = true,
    int pages = 100,
    String name = 'Personal',
  }) => profiles.create(
    name: name,
    baseUrl: 'https://${name.toLowerCase()}.example/v1',
    apiKey: '$name-private-key-1234',
    defaultModelId: 'claude-book',
    pdfAttachmentsEnabled: pdf,
    pdfMaxPages: pages,
  );
  AiPdfDocument document({List<int> pages = const [1, 2, 3]}) => AiPdfDocument(
    bytes: _pdfFixture(),
    fileName: 'textbook.pdf',
    sourcePages: pages,
  );
  RoutingPdfAiCompletionClient router(http.Client client) {
    final api = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      profiles: profiles,
      httpClient: client,
    );
    addTearDown(api.dispose);
    return RoutingPdfAiCompletionClient(
      gemini: GeminiAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      ),
      deepSeek: DeepSeekAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      ),
      newApi: api,
    );
  }

  Future<ReferenceBook> book({bool indexed = false}) async {
    await repository.createBook(
      id: 'book',
      title: 'Study Book',
      originalFileName: 'textbook.pdf',
      storedFileName: 'book.pdf',
      pageCount: 3,
      chapters: [
        const DetectedChapter(
          title: 'Second chapter',
          level: 0,
          startPage: 2,
          endPage: 3,
        ),
      ],
    );
    final value = (await repository.book('book'))!;
    if (indexed) {
      await repository.startIndex(value);
      await repository.savePages(value.id, const [
        BookPage(1, 'Introduction'),
        BookPage(2, 'Risk register probability impact.'),
        BookPage(3, 'Cost baseline and budget.'),
      ]);
    }
    return value;
  }

  http.Response claudeResponse([String text = 'Answer [p. 2].']) =>
      http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': text},
          ],
          'usage': {'input_tokens': 50, 'output_tokens': 20},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

  test(
    'custom PDF attachment uses the selected profile URL, key, model, and document block',
    () async {
      final personal = await profile();
      final university = await profile(name: 'University');
      await settings.setActiveEndpointProfileId(university.id);
      Map? sent;
      final client = router(
        MockClient((r) async {
          expect(r.url.toString(), 'https://personal.example/v1/messages');
          expect(
            r.headers['Authorization'],
            'Bearer Personal-private-key-1234',
          );
          sent = jsonDecode(r.body) as Map;
          return claudeResponse();
        }),
      );
      final picked = selection(AiProviderId.newApi, profileId: personal.id);
      final result = await client.completeWithPdf(
        messages: const [
          {'role': 'system', 'content': 'Use the supplied book.'},
          {'role': 'user', 'content': 'Explain page 2.'},
        ],
        document: document(),
        maxOutputTokens: 100,
        selection: picked,
      );
      expect(sent!['model'], 'claude-book');
      expect(sent!['stream'], isTrue);
      final blocks = (sent!['messages'] as List).first['content'] as List;
      expect(blocks.first['type'], 'document');
      expect(blocks.first['source']['media_type'], 'application/pdf');
      expect(
        base64Decode(blocks.first['source']['data'] as String),
        _pdfFixture(),
      );
      expect(blocks.last, {'type': 'text', 'text': 'Explain page 2.'});
      expect(result.model, picked.persistedModelId);
      expect(await credentials.hasApiKeyFor(AiProviderId.gemini), isFalse);
      expect(metadata.value, isNot(contains('JVBER')));
      expect(metadata.value, isNot(contains('private-key')));
    },
  );

  test(
    'custom API text mode works with PDF capability off and no Gemini key',
    () async {
      final value = await book(indexed: true);
      final target = await profile(pdf: false);
      final bodies = <Map>[];
      final client = router(
        MockClient((request) async {
          expect(request.url.host, 'personal.example');
          final body = jsonDecode(request.body) as Map;
          bodies.add(body);
          return claudeResponse(
            body['max_tokens'] == 256
                ? 'risk register'
                : 'Risk is tracked [p. 2].',
          );
        }),
      );
      final ai = BookAiService(
        repository,
        BookSearchService(repository, _RejectEmbeddings()),
        client,
      );
      await ai.ask(
        book: value,
        question: 'Risk register?',
        selection: selection(AiProviderId.newApi, profileId: target.id),
      );
      expect(bodies.last['messages'][0]['content'], isA<String>());
      expect(bodies.last['messages'][0]['content'], contains('SOURCE PAGES:'));
      expect((await repository.messages(value.id)).last.provider, 'newApi');
      expect(await credentials.hasApiKeyFor(AiProviderId.gemini), isFalse);
    },
  );

  test(
    'PDF capability and page limits are enforced before any HTTP request',
    () async {
      final target = await profile(pdf: false, pages: 1);
      var requests = 0;
      final client = router(
        MockClient((_) async {
          requests++;
          return claudeResponse();
        }),
      );
      final picked = selection(AiProviderId.newApi, profileId: target.id);
      Future<PdfAiCompletion> run() => client.completeWithPdf(
        messages: const [
          {'role': 'user', 'content': 'Explain'},
        ],
        document: document(),
        maxOutputTokens: 50,
        selection: picked,
      );
      await expectLater(run(), throwsA(isA<AiNotConfiguredException>()));
      await profiles.update(id: target.id, pdfAttachmentsEnabled: true);
      await expectLater(run(), throwsA(isA<AiMalformedOutputException>()));
      expect(requests, 0);
    },
  );

  test(
    'disabling/deleting a profile cannot redirect a pending PDF request to another profile',
    () async {
      final target = await profile();
      final other = await profile(name: 'University');
      await settings.setActiveEndpointProfileId(other.id);
      var requests = 0;
      final client = router(
        MockClient((_) async {
          requests++;
          return claudeResponse();
        }),
      );
      final picked = selection(AiProviderId.newApi, profileId: target.id);
      await profiles.delete(target.id);
      await expectLater(
        client.completeWithPdf(
          messages: const [
            {'role': 'user', 'content': 'Explain'},
          ],
          document: document(),
          maxOutputTokens: 50,
          selection: picked,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requests, 0);
    },
  );

  test(
    'Gemini receives native PDF inline data and a separate system instruction',
    () async {
      await credentials.saveApiKeyFor(AiProviderId.gemini, 'gemini-test-key');
      Map? sent;
      final client = router(
        MockClient((r) async {
          expect(r.url.path, contains('generateContent'));
          sent = jsonDecode(r.body) as Map;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Read [p. 2].'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      await client.completeWithPdf(
        messages: const [
          {'role': 'system', 'content': 'Use only the book.'},
          {'role': 'user', 'content': 'Explain page 2.'},
        ],
        document: document(),
        maxOutputTokens: 100,
        selection: selection(AiProviderId.gemini),
      );
      expect(
        sent!['systemInstruction']['parts'][0]['text'],
        'Use only the book.',
      );
      final parts = sent!['contents'][0]['parts'] as List;
      expect(parts.first['inlineData']['mimeType'], 'application/pdf');
      expect(
        base64Decode(parts.first['inlineData']['data'] as String),
        _pdfFixture(),
      );
    },
  );

  test(
    'DeepSeek remains available for text and rejects native PDFs without a misleading upload',
    () async {
      await credentials.saveApiKeyFor(
        AiProviderId.deepseek,
        'deepseek-test-key',
      );
      var requests = 0;
      final client = router(
        MockClient((r) async {
          requests++;
          expect(r.url.host, 'api.deepseek.com');
          final body = jsonDecode(r.body) as Map;
          expect(body['messages'][1]['content'], contains('Risk register'));
          return http.Response(
            '{"choices":[{"message":{"content":"Risk register [p. 2]."}}]}',
            200,
          );
        }),
      );
      final picked = selection(AiProviderId.deepseek);
      final result = await client.complete(
        messages: const [
          {'role': 'system', 'content': 'Study companion'},
          {'role': 'user', 'content': 'Risk register probability'},
        ],
        maxOutputTokens: 100,
        selection: picked,
      );
      expect(result.provider, 'deepseek');
      await expectLater(
        client.completeWithPdf(
          messages: const [
            {'role': 'user', 'content': 'Explain'},
          ],
          document: document(),
          maxOutputTokens: 100,
          selection: picked,
        ),
        throwsA(isA<AiUnsupportedModelException>()),
      );
      expect(requests, 1);
      expect(await credentials.hasApiKeyFor(AiProviderId.gemini), isFalse);
    },
  );

  test(
    'PDF profile metadata is backward compatible, validated, and round trips',
    () async {
      final target = await profile(pdf: true, pages: 600);
      final saved = AiEndpointProfile.fromJson(target.toJson());
      expect(saved.pdfAttachmentsEnabled, isTrue);
      expect(saved.pdfMaxPages, 600);
      final legacy = target.toJson()
        ..remove('pdfAttachmentsEnabled')
        ..remove('pdfMaxPages');
      expect(AiEndpointProfile.fromJson(legacy).pdfAttachmentsEnabled, isFalse);
      expect(AiEndpointProfile.fromJson(legacy).pdfMaxPages, 100);
      await expectLater(
        profiles.update(id: target.id, pdfMaxPages: 601),
        throwsFormatException,
      );
      expect((await profiles.find(target.id))!.pdfMaxPages, 600);
    },
  );

  test(
    'PDF Ask works without a text index and keeps the source prefix stable across turns',
    () async {
      final value = await book();
      final target = await profile();
      final requests = <Map>[];
      final client = router(
        MockClient((r) async {
          requests.add(jsonDecode(r.body) as Map);
          return claudeResponse();
        }),
      );
      final source = _FakePdfSource(document());
      final ai = BookAiService(
        repository,
        BookSearchService(repository, _RejectEmbeddings()),
        client,
        pdfSource: source,
      );
      final picked = selection(AiProviderId.newApi, profileId: target.id);
      await ai.ask(
        book: value,
        question: 'Explain the diagram',
        selection: picked,
        inputMode: BookAiInputMode.pdfAttachment,
      );
      await ai.ask(
        book: value,
        question: 'Give an example',
        selection: picked,
        inputMode: BookAiInputMode.pdfAttachment,
      );
      expect(requests[0]['messages'][0], requests[1]['messages'][0]);
      expect(source.requests, [null, null]);
      final rows = await repository.messages(value.id);
      expect(rows.map((m) => m.role), [
        'user',
        'assistant',
        'user',
        'assistant',
      ]);
      expect(jsonDecode(rows.last.sourcePages!), [2]);
      expect(rows.last.model, picked.persistedModelId);
    },
  );

  test(
    'PDF chapter/page explanations send only their page range without an index',
    () async {
      final value = await book();
      final target = await profile();
      final client = router(
        MockClient((_) async => claudeResponse('Diagram explained [p. 2].')),
      );
      final source = _FakePdfSource(document());
      final ai = BookAiService(
        repository,
        BookSearchService(repository, _RejectEmbeddings()),
        client,
        pdfSource: source,
      );
      final picked = selection(AiProviderId.newApi, profileId: target.id);
      final chapter = (await repository.chapters(value.id)).single;
      final brief = await ai.generateChapterItem(
        book: value,
        chapter: chapter,
        kind: BookAiKind.brief,
        selection: picked,
        inputMode: BookAiInputMode.pdfAttachment,
      );
      final explanation = await ai.explainPages(
        book: value,
        startPage: 2,
        endPage: 2,
        selection: picked,
        inputMode: BookAiInputMode.pdfAttachment,
      );
      expect(source.requests, [
        [2, 3],
        [2],
      ]);
      expect(brief.provider, 'newApi');
      expect(explanation.startPage, 2);
    },
  );

  test(
    'DeepSeek/custom retrieval never calls Gemini embeddings even if vectors exist',
    () async {
      final value = await book(indexed: true);
      final embeddings = _RejectEmbeddings();
      await repository.finishVectors(value.id, embeddings.model);
      final client = _TextClient();
      final ai = BookAiService(
        repository,
        BookSearchService(repository, embeddings),
        client,
      );
      await ai.ask(
        book: value,
        question: 'Risk register?',
        selection: selection(AiProviderId.deepseek),
      );
      expect(embeddings.calls, 0);
      expect(
        client.selections.every((s) => s.provider == AiProviderId.deepseek),
        isTrue,
      );
      final sent = client.requests.last;
      expect(sent[1]['content'], contains('SOURCE PAGES:'));
      expect((await repository.messages(value.id)).last.provider, 'deepseek');
    },
  );

  test(
    'partial PDF replies are not saved as completed book materials',
    () async {
      final value = await book();
      final client = _PartialFileClient();
      final ai = BookAiService(
        repository,
        BookSearchService(repository, _RejectEmbeddings()),
        client,
        pdfSource: _FakePdfSource(document()),
      );
      await expectLater(
        ai.explainPages(
          book: value,
          startPage: 2,
          endPage: 2,
          selection: selection(AiProviderId.gemini),
          inputMode: BookAiInputMode.pdfAttachment,
        ),
        throwsA(isA<AiConnectionInterruptedException>()),
      );
      expect(
        await repository.latestAiItem(
          bookId: value.id,
          kind: BookAiKind.explanation,
          scopeKey: 'pages:2-2',
        ),
        isNull,
      );
    },
  );

  test(
    'native PDF slices retain only selected pages, in original order with original citations',
    () async {
      await pdfrxInitialize(tmpPath: directory.path);
      addTearDown(() => PdfrxEntryFunctions.instance.stopBackgroundWorker());
      final value = await book();
      final file = File('${directory.path}/source.pdf')
        ..writeAsBytesSync(_pdfFixture());
      final source = LocalBookPdfSource(resolvePath: (_) async => file.path);
      final excerpt = await source.prepare(value, pages: [3, 2], maxPages: 100);
      expect(excerpt.sourcePages, [2, 3]);
      expect(excerpt.pageMap, contains('Attached page 1 = book page 2'));
      final output = await PdfDocument.openData(excerpt.bytes);
      try {
        expect(output.pages, hasLength(2));
        final texts = [
          for (final p in output.pages) (await p.loadText())!.fullText,
        ];
        expect(texts.first, contains('Book page two'));
        expect(texts.last, contains('Book page three'));
        expect(texts.join(), isNot(contains('Book page one')));
      } finally {
        await output.dispose();
      }
    },
  );

  test(
    'whole PDF uses original bytes and enforces file/page limits before reading',
    () async {
      await pdfrxInitialize(tmpPath: directory.path);
      addTearDown(() => PdfrxEntryFunctions.instance.stopBackgroundWorker());
      final value = await book();
      final file = File('${directory.path}/source.pdf')
        ..writeAsBytesSync(_pdfFixture());
      final source = LocalBookPdfSource(resolvePath: (_) async => file.path);
      final full = await source.prepare(value, maxPages: 100);
      expect(full.bytes, _pdfFixture());
      await expectLater(
        source.prepare(value, maxPages: 2),
        throwsA(isA<AiMalformedOutputException>()),
      );
      final handle = await file.open(mode: FileMode.append);
      await handle.truncate(AiPdfDocument.maxBytes + 1);
      await handle.close();
      await expectLater(
        source.prepare(value, maxPages: 100),
        throwsA(isA<AiMalformedOutputException>()),
      );
    },
  );

  testWidgets('book model picker works with a DeepSeek key and no Gemini key', (
    tester,
  ) async {
    await credentials.saveApiKeyFor(AiProviderId.deepseek, 'deepseek-test-key');
    BookAiRequest? chosen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCredentialStoreProvider.overrideWithValue(credentials),
          aiSettingsStoreProvider.overrideWithValue(settings),
          aiEndpointProfilesProvider.overrideWith((ref) async => []),
          availableAiModelsProvider.overrideWith(
            (ref, constraints) async => [
              const AiSelectableModel(
                id: 'deepseek-flash',
                displayName: 'DeepSeek Book Model',
                description: 'Book text',
                recommended: true,
                group: 'DeepSeek',
                provider: AiProviderId.deepseek,
              ),
            ],
          ),
        ],
        child: MaterialApp(home: _ChooseBookModel(onChosen: (v) => chosen = v)),
      ),
    );
    await tester.tap(find.text('Choose book model'));
    await tester.pumpAndSettle();
    expect(find.text('DeepSeek Book Model'), findsOneWidget);
    expect(find.textContaining('API key required'), findsNothing);
    await tester.tap(find.text('DeepSeek Book Model'));
    await tester.pumpAndSettle();
    expect(chosen?.selection.provider, AiProviderId.deepseek);
    expect(chosen?.inputMode, BookAiInputMode.extractedText);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'PDF attachment is an explicit reachable source choice on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      BookAiInputMode? chosen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pdfAiCompletionClientProvider.overrideWithValue(
              _PartialFileClient(),
            ),
          ],
          child: MaterialApp(
            home: _ChooseInput(onChosen: (mode) => chosen = mode),
          ),
        ),
      );
      await tester.tap(find.text('Choose source'));
      await tester.pumpAndSettle();
      expect(find.text('Entire book: 3 pages'), findsOneWidget);
      await tester.tap(find.text('Attach PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this mode'));
      await tester.pumpAndSettle();
      expect(chosen, BookAiInputMode.pdfAttachment);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cancelling model selection never falls back to the global default',
    (tester) async {
      var completed = false;
      BookAiRequest? chosen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSettingsStoreProvider.overrideWithValue(settings),
            aiEndpointProfilesProvider.overrideWith((ref) async => []),
            availableAiModelsProvider.overrideWith(
              (ref, constraints) async => [],
            ),
          ],
          child: MaterialApp(
            home: _ChooseBookModel(
              onChosen: (v) {
                completed = true;
                chosen = v;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose book model'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(chosen, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ChooseInput extends ConsumerWidget {
  const _ChooseInput({required this.onChosen});
  final void Function(BookAiInputMode?) onChosen;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: TextButton(
      onPressed: () async => onChosen(
        await chooseBookInputMode(
          context,
          ref,
          selection: AiExecutionSelection.fromStored(
            provider: AiProviderId.gemini,
            modelId: 'gemini-3.8-flash',
          ),
          pageCount: 3,
          sourceDescription: 'Entire book: 3 pages',
        ),
      ),
      child: const Text('Choose source'),
    ),
  );
}

class _ChooseBookModel extends ConsumerWidget {
  const _ChooseBookModel({required this.onChosen});
  final void Function(BookAiRequest?) onChosen;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: TextButton(
      onPressed: () async => onChosen(
        await pickBookAiRequest(
          context,
          ref,
          title: 'Book model',
          pageCount: 3,
          sourceDescription: 'Book chapter',
        ),
      ),
      child: const Text('Choose book model'),
    ),
  );
}

class _FakePdfSource implements BookPdfSource {
  _FakePdfSource(this.document);
  final AiPdfDocument document;
  final requests = <List<int>?>[];
  @override
  Future<AiPdfDocument> prepare(
    ReferenceBook book, {
    List<int>? pages,
    required int maxPages,
  }) async {
    requests.add(pages == null ? null : List.of(pages));
    return AiPdfDocument(
      bytes: document.bytes,
      fileName: document.fileName,
      sourcePages: pages ?? document.sourcePages,
    );
  }
}

class _RejectEmbeddings implements BookEmbeddingClient {
  int calls = 0;
  @override
  String get model => 'gemini-embedding-test';
  @override
  Future<bool> get isAvailable async => true;
  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool query,
  }) async {
    calls++;
    throw StateError(
      'A DeepSeek/custom request must not call Gemini embeddings.',
    );
  }
}

class _TextClient implements PdfAiCompletionClient {
  final selections = <AiExecutionSelection>[];
  final requests = <List<Map<String, String>>>[];
  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) async {
    selections.add(selection);
    requests.add(messages);
    return PdfAiCompletion(
      markdown: maxOutputTokens == 256
          ? 'risk register'
          : 'Risk register [p. 2].',
      provider: selection.providerStorage,
      model: selection.persistedModelId,
    );
  }
}

class _PartialFileClient extends _TextClient
    implements PdfAiFileCompletionClient {
  @override
  Future<int> pdfPageLimit(AiExecutionSelection selection) async => 100;
  @override
  Future<PdfAiCompletion> completeWithPdf({
    required List<Map<String, String>> messages,
    required AiPdfDocument document,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) async => const PdfAiCompletion(
    markdown: 'Interrupted explanation',
    provider: 'gemini',
    model: 'gemini',
    disposition: AiCompletionDisposition.partialTimeout,
  );
}

Uint8List _pdfFixture() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R] /Count 3 >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  for (final word in ['one', 'two', 'three']) {
    final contentId = objects.length + 2;
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentId 0 R >>',
    );
    final stream = 'BT /F1 12 Tf 72 720 Td (Book page $word) Tj ET';
    objects.add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  }
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final startXref = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final at in offsets.skip(1)) {
    buffer.write('${at.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
