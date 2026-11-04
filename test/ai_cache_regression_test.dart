import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_endpoint_profile_repository.dart';
import 'package:study_vault/features/ai_assistant/data/ai_model_catalog_providers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_providers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_request_metrics_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_endpoint_profile.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_token_usage.dart';
import 'package:study_vault/features/ai_assistant/domain/annotation_ai_context.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/new_api_claude_service.dart';
import 'package:study_vault/features/ai_chat/data/ai_chat_providers.dart';
import 'package:study_vault/features/ai_chat/data/chat_request_preferences.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/chat_history_policy.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/measured_ai_chat_transport.dart';
import 'package:study_vault/features/ai_chat/services/new_api_claude_chat_service.dart';
import 'helpers/ai_selection_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryAiSettingsStore settings;
  late MemoryAiCredentialStore credentials;
  late MemoryAiEndpointCatalogStore metadata;
  late AiEndpointProfileRepository profiles;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = MemoryAiSettingsStore();
    credentials = MemoryAiCredentialStore();
    metadata = MemoryAiEndpointCatalogStore();
    profiles = AiEndpointProfileRepository(
      store: metadata,
      settings: settings,
      credentials: credentials,
    );
  });
  tearDown(() => profiles.dispose());

  Future<AiEndpointProfile> create({String name = 'Personal'}) =>
      profiles.create(
        name: name,
        baseUrl: 'https://example.com/v1',
        apiKey: 'private-key-1234',
        defaultModelId: 'claude-a',
      );
  NewApiClaudeService service(http.Client client) {
    final result = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      profiles: profiles,
      httpClient: client,
    );
    addTearDown(result.dispose);
    return result;
  }

  group('Model catalog consistency', () {
    test(
      'URL and credential changes invalidate models even for identical key suffixes',
      () async {
        final profile = await create();
        await profiles.cacheModels(id: profile.id, modelIds: ['old']);
        await profiles.update(
          id: profile.id,
          replacementApiKey: 'different-key-1234',
        );
        var changed = (await profiles.find(profile.id))!;
        expect(changed.cachedModelIds, isEmpty);
        expect(changed.modelsRefreshedAt, isNull);
        expect(changed.modelsStale, isTrue);
        expect(changed.connectionRevision, 1);
        expect(changed.connectionStatus, AiEndpointConnectionStatus.unknown);
        await profiles.cacheModels(id: profile.id, modelIds: ['new']);
        await profiles.update(id: profile.id, name: 'Renamed');
        expect((await profiles.find(profile.id))!.cachedModelIds, ['new']);
        changed = await profiles.update(
          id: profile.id,
          baseUrl: 'https://new.example/v1',
        );
        expect(changed.cachedModelIds, isEmpty);
        expect(changed.connectionRevision, 2);
      },
    );

    test('concurrent profile writes preserve both updates', () async {
      final a = await create();
      final b = await create(name: 'University');
      await Future.wait([
        profiles.cacheModels(id: a.id, modelIds: ['a']),
        profiles.cacheModels(id: b.id, modelIds: ['b']),
        profiles.update(id: a.id, name: 'Updated'),
      ]);
      expect((await profiles.find(a.id))!.cachedModelIds, ['a']);
      expect((await profiles.find(a.id))!.name, 'Updated');
      expect((await profiles.find(b.id))!.cachedModelIds, ['b']);
    });

    test('overlapping refreshes share one GET', () async {
      final profile = await create();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final api = service(
        MockClient((_) {
          calls++;
          if (!started.isCompleted) started.complete();
          return response.future;
        }),
      );
      final a = api.refreshCachedModels(profile.id);
      await started.future;
      final b = api.refreshCachedModels(profile.id);
      await Future<void>.delayed(Duration.zero);
      response.complete(http.Response('{"data":[{"id":" model-a "}]}', 200));
      expect(await a, ['model-a']);
      expect(await b, ['model-a']);
      expect(calls, 1);
    });

    test(
      'late refresh cannot overwrite an edited connection or its cache',
      () async {
        final profile = await create();
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final api = service(
          MockClient((_) {
            started.complete();
            return response.future;
          }),
        );
        final pending = api.refreshCachedModels(profile.id);
        final failure = expectLater(
          pending,
          throwsA(isA<AiProfileUnavailableException>()),
        );
        await started.future;
        await profiles.update(
          id: profile.id,
          baseUrl: 'https://new.example/v1',
        );
        await profiles.cacheModels(
          id: profile.id,
          modelIds: ['new-server-model'],
        );
        response.complete(
          http.Response('{"data":[{"id":"old-server-model"}]}', 200),
        );
        await failure;
        final saved = (await profiles.find(profile.id))!;
        expect(saved.cachedModelIds, ['new-server-model']);
        expect(saved.connectionStatus, AiEndpointConnectionStatus.ok);
      },
    );

    test('deleting a profile during refresh cannot resurrect it', () async {
      final profile = await create();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final api = service(
        MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final pending = api.refreshCachedModels(profile.id);
      final failure = expectLater(
        pending,
        throwsA(isA<AiProfileUnavailableException>()),
      );
      await started.future;
      await profiles.delete(profile.id);
      response.complete(http.Response('{"data":[]}', 200));
      await failure;
      expect(await profiles.find(profile.id), isNull);
    });

    test(
      'failed automatic refresh retains models and observes retry cooldown',
      () async {
        final profile = await create();
        await profiles.cacheModels(id: profile.id, modelIds: ['saved']);
        final stale = (await profiles.find(
          profile.id,
        ))!.copyWith(modelsRefreshedAt: DateTime(2000));
        var calls = 0;
        final api = service(
          MockClient((_) async {
            calls++;
            return http.Response('offline', 503);
          }),
        );
        await api.refreshModelsIfStale(stale);
        await api.refreshModelsIfStale(stale);
        expect(calls, 1);
        expect((await profiles.find(profile.id))!.cachedModelIds, ['saved']);
        await expectLater(
          api.refreshCachedModels(profile.id),
          throwsA(isA<AiServerException>()),
        );
        expect(calls, 2); // Explicit retry bypasses the automatic cooldown.
      },
    );

    test(
      'picker returns cached custom models while other providers are blocked',
      () async {
        final profile = await create();
        await profiles.cacheModels(id: profile.id, modelIds: ['cached-custom']);
        final blocked = Completer<List<AiSelectableModel>>();
        final fake = _RecordingTransport(
          credentials,
          settings,
          models: blocked.future,
        );
        final container = ProviderContainer(
          overrides: [
            aiSettingsStoreProvider.overrideWithValue(settings),
            aiCredentialStoreProvider.overrideWithValue(credentials),
            aiEndpointProfileRepositoryProvider.overrideWithValue(profiles),
            geminiChatServiceProvider.overrideWithValue(fake),
            deepseekChatServiceProvider.overrideWithValue(fake),
            pocketChatServiceProvider.overrideWithValue(fake),
          ],
        );
        addTearDown(container.dispose);
        container.listen(
          availableAiModelsProvider(AiExecutionConstraints.none),
          (_, _) {},
        );
        final rows = await container
            .read(availableAiModelsProvider(AiExecutionConstraints.none).future)
            .timeout(const Duration(seconds: 2));
        expect(rows.any((m) => m.displayName == 'cached-custom'), isTrue);
        expect(blocked.isCompleted, isFalse);
        blocked.complete([]);
      },
    );
  });

  test('catalog subscribers observe successive repository changes', () async {
    final profile = await create();
    final container = ProviderContainer(
      overrides: [
        aiEndpointProfileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    final observed = <List<AiEndpointProfile>>[];
    container.listen(aiEndpointProfilesProvider, (_, next) {
      if (next.hasValue) observed.add(next.requireValue);
    }, fireImmediately: true);
    await container.read(aiEndpointProfilesProvider.future);
    await profiles.cacheModels(id: profile.id, modelIds: ['first']);
    await container.pump();
    expect(
      (await container.read(
        aiEndpointProfilesProvider.future,
      )).single.cachedModelIds,
      ['first'],
    );
    await profiles.cacheModels(id: profile.id, modelIds: ['second']);
    await container.pump();
    expect(
      (await container.read(
        aiEndpointProfilesProvider.future,
      )).single.cachedModelIds,
      ['second'],
    );
    expect(observed.last.single.cachedModelIds, ['second']);
  });

  group('Local answer cache identity', () {
    const context = AnnotationAiContext(
      selectedText: 'Gradient descent',
      pageNumber: 2,
    );
    test(
      'interleaved requests deduplicate by their complete identity',
      () async {
        final gates = <String, Completer<AiStudyResult>>{};
        var calls = 0;
        final ai = AnnotationAiService(
          aiService: FakeAiService(
            handler: (r) {
              calls++;
              return gates
                  .putIfAbsent(r.sourceText, Completer<AiStudyResult>.new)
                  .future;
            },
          ),
        );
        Future<AiStudyResult> run(String text) => ai.run(
          context: AnnotationAiContext(selectedText: text),
          action: AiStudyAction.explain,
          selection: testGeminiSelection(),
        );
        final a = run('A');
        final b = run('B');
        final aAgain = run('A');
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2);
        gates['A']!.complete(const AiTextResult(markdown: 'A answer'));
        gates['B']!.complete(const AiTextResult(markdown: 'B answer'));
        final result = await Future.wait([a, b, aAgain]);
        expect(identical(result[0], result[2]), isTrue);
      },
    );

    test(
      'different histories never deduplicate the same follow-up question',
      () async {
        final gate = Completer<void>();
        var calls = 0;
        final ai = AnnotationAiService(
          aiService: FakeAiService(
            handler: (r) async {
              calls++;
              await gate.future;
              return AiTextResult(
                markdown: r.conversation.first.assistantMarkdown,
              );
            },
          ),
        );
        Future<AiStudyResult> run(String answer) => ai.run(
          context: context,
          action: AiStudyAction.askAi,
          selection: testGeminiSelection(),
          customPrompt: 'Why?',
          conversation: [
            AiConversationTurn(
              userMessage: 'Earlier',
              assistantMarkdown: answer,
            ),
          ],
        );
        final a = run('First');
        final b = run('Second');
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2);
        gate.complete();
        expect((await a as AiTextResult).markdown, 'First');
        expect((await b as AiTextResult).markdown, 'Second');
      },
    );

    test(
      'image bytes, style, and category IDs are part of cache identity',
      () async {
        var calls = 0;
        final ai = AnnotationAiService(
          settings: settings,
          aiService: FakeAiService(
            handler: (_) async {
              calls++;
              return const AiTextResult(markdown: 'answer');
            },
          ),
        );
        Future<AiStudyResult> run(int image, {String category = 'one'}) =>
            ai.run(
              context: context,
              action: AiStudyAction.explain,
              selection: testGeminiSelection(),
              image: AiStudyImage(
                bytes: Uint8List.fromList([image]),
                mimeType: 'image/jpeg',
              ),
              categoryNameToId: {'Definition': category},
            );
        await run(1);
        await run(1);
        expect(calls, 1);
        await run(2);
        await settings.setStudyPreference('Use Persian explanations.');
        await run(2);
        await run(2, category: 'two');
        expect(calls, 4);
      },
    );

    test(
      'identical model IDs on different profiles do not share answers',
      () async {
        final a = await create();
        final b = await create(name: 'Other');
        var calls = 0;
        final ai = AnnotationAiService(
          profiles: profiles,
          aiService: FakeAiService(
            handler: (_) async {
              calls++;
              return const AiTextResult(markdown: 'answer');
            },
          ),
        );
        Future<AiStudyResult> run(AiEndpointProfile p) => ai.run(
          context: context,
          action: AiStudyAction.explain,
          selection: AiExecutionSelection.fromStored(
            provider: AiProviderId.newApi,
            modelId: 'claude-a',
            endpointProfileId: p.id,
          ),
        );
        await run(a);
        await run(b);
        expect(calls, 2);
        await profiles.update(id: a.id, replacementApiKey: 'changed-key-1234');
        await run(a);
        expect(calls, 3);
        await profiles.update(id: a.id, enabled: false);
        await expectLater(
          run(a),
          throwsA(isA<AiProfileUnavailableException>()),
        );
      },
    );

    test('partial responses are never reused as completed answers', () async {
      var calls = 0;
      final ai = AnnotationAiService(
        aiService: FakeAiService(
          handler: (_) async {
            calls++;
            return const AiTextResult(
              markdown: 'partial',
              disposition: AiCompletionDisposition.partialTimeout,
            );
          },
        ),
      );
      for (var i = 0; i < 2; i++) {
        await ai.run(
          context: context,
          action: AiStudyAction.explain,
          selection: testGeminiSelection(),
        );
      }
      expect(calls, 2);
    });
  });

  group('Stable conversation requests', () {
    test(
      'title is a separate request and subsequent history remains verbatim',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final transport = _RecordingTransport(credentials, settings);
        final snapshots = MemoryChatRequestPreferences();
        await settings.setStudyPreference('Use concise answers.');
        final ai = AiChatService(
          db: db,
          settings: settings,
          transport: transport,
          requestPreferences: snapshots,
        );
        final chat = await ai.createChat();
        await ai.sendMessage(
          chatId: chat.id,
          userText: 'Explain gradient descent',
        );
        expect(transport.requests, hasLength(2));
        final first = transport.requests.first;
        expect(transport.requests[1].single.outputTokenLimit, 128);
        expect(first.single.content, 'Explain gradient descent');
        expect(
          transport.requests[1].single.content,
          contains('Return exactly [[CHAT_TITLE:'),
        );
        expect((await db.getAiChatById(chat.id))!.title, 'Gradient Descent');
        await settings.setStudyPreference('Use very long answers.');
        await ai.sendMessage(chatId: chat.id, userText: 'Give an example');
        final next = transport.requests.last;
        expect(next.first.content, first.first.content);
        expect(next.first.systemPreference, first.first.systemPreference);
        expect(next[1].content, 'Study answer');
        expect(next.last.content, 'Give an example');
      },
    );

    test(
      'style snapshots survive restart and can be removed with a chat',
      () async {
        final first = LocalChatRequestPreferences();
        expect(
          await first.capture('chat', 'model', () async => 'Original'),
          'Original',
        );
        final restarted = LocalChatRequestPreferences();
        expect(
          await restarted.capture('chat', 'model', () async => 'Changed'),
          'Original',
        );
        await restarted.remove('chat');
        expect(
          await restarted.capture('chat', 'model', () async => 'Changed'),
          'Changed',
        );
      },
    );

    test(
      'compaction keeps source and latest question, then appends a stable suffix',
      () {
        final history = <AiChatTurn>[
          const AiChatTurn(
            role: 'user',
            content: 'Original source',
            pinForCache: true,
          ),
        ];
        for (var i = 0; i < 21; i++) {
          history.add(AiChatTurn(role: 'assistant', content: 'Answer $i'));
          history.add(AiChatTurn(role: 'user', content: 'Question $i'));
        }
        final first = ChatHistoryPolicy.compact(history, maxMessages: 12);
        expect(first.first.content, 'Original source');
        expect(first.last.content, 'Question 20');
        expect(
          first.any((t) => t.content.contains('EARLIER CONVERSATION EXCERPTS')),
          isTrue,
        );
        history.add(
          const AiChatTurn(role: 'assistant', content: 'Latest answer'),
        );
        history.add(const AiChatTurn(role: 'user', content: 'New question'));
        final second = ChatHistoryPolicy.compact(history, maxMessages: 12);
        expect(
          second.take(first.length).map((t) => [t.role, t.content]),
          first.map((t) => [t.role, t.content]),
        );
      },
    );

    test('oversized source and latest question cannot silently disappear', () {
      expect(
        () => ChatHistoryPolicy.compact([
          AiChatTurn(role: 'user', content: 'x' * 1000, pinForCache: true),
          const AiChatTurn(role: 'assistant', content: 'Answer'),
          const AiChatTurn(role: 'user', content: 'Latest'),
        ], maxTokens: 100),
        throwsA(isA<AiServerException>()),
      );
      expect(
        () => ChatHistoryPolicy.compact([
          const AiChatTurn(role: 'user', content: 'Source', pinForCache: true),
          const AiChatTurn(role: 'assistant', content: 'Answer'),
          AiChatTurn(role: 'user', content: 'x' * 1000),
        ], maxTokens: 100),
        throwsA(isA<AiServerException>()),
      );
    });

    test('Gemini HTTP retains source after more than 40 turns', () async {
      await credentials.saveApiKeyFor(AiProviderId.gemini, 'gemini-test-key');
      await settings.setPrivacyConsentAccepted(true);
      final api = HttpGeminiChatService(
        credentials: credentials,
        settings: settings,
        httpClient: MockClient((r) async {
          final body = jsonDecode(r.body) as Map;
          final contents = body['contents'] as List;
          expect(jsonEncode(contents.first), contains('Original source'));
          expect(jsonEncode(contents.last), contains('Question 24'));
          return http.Response(
            '{"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}',
            200,
          );
        }),
      );
      final history = <AiChatTurn>[
        const AiChatTurn(
          role: 'user',
          content: 'Original source',
          pinForCache: true,
        ),
      ];
      for (var i = 0; i < 25; i++) {
        history.add(AiChatTurn(role: 'assistant', content: 'Answer $i'));
        history.add(AiChatTurn(role: 'user', content: 'Question $i'));
      }
      await api.complete(modelId: 'gemini-3.8-flash', history: history);
    });
  });

  group('Claude caching and diagnostics', () {
    test(
      'Claude cache configuration is opt-in per endpoint on complete and stream',
      () async {
        final profile = await create();
        await settings.setPrivacyConsentAccepted(true);
        final requests = <Map<String, dynamic>>[];
        final api = service(
          MockClient((r) async {
            requests.add((jsonDecode(r.body) as Map).cast<String, dynamic>());
            return http.Response(
              '{"content":[{"type":"text","text":"ok"}]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final transport = NewApiClaudeChatService(
          service: api,
          settings: settings,
          profiles: profiles,
        );
        final modelId = AiExecutionSelection.fromStored(
          provider: AiProviderId.newApi,
          modelId: 'claude-a',
          endpointProfileId: profile.id,
        ).modelRef.storageValue;
        const history = [
          AiChatTurn(
            role: 'user',
            content: 'Source and question',
            outputTokenLimit: 128,
          ),
        ];
        await transport.complete(modelId: modelId, history: history);
        expect(requests.last.containsKey('cache_control'), isFalse);
        expect(requests.last['max_tokens'], 128);
        await profiles.update(id: profile.id, promptCachingEnabled: true);
        await transport.complete(modelId: modelId, history: history);
        await transport
            .streamComplete(modelId: modelId, history: history)
            .toList();
        expect(requests[1]['cache_control'], {'type': 'ephemeral'});
        expect(requests[2]['cache_control'], {'type': 'ephemeral'});
        expect((await profiles.find(profile.id))!.promptCachingEnabled, isTrue);
        expect(
          AiEndpointProfile.fromJson(
            (await profiles.find(profile.id))!.toJson(),
          ).promptCachingEnabled,
          isTrue,
        );
      },
    );

    test('Claude reads, writes, and uncached input remain distinct', () {
      final api = service(MockClient((_) async => http.Response('', 200)));
      final usage = api.usage({
        'usage': {
          'input_tokens': 20,
          'cache_read_input_tokens': 100,
          'cache_creation_input_tokens': 50,
          'output_tokens': 10,
        },
      }, 'claude-a')!;
      expect(usage.promptTokens, 170);
      expect(usage.cacheHitTokens, 100);
      expect(usage.cacheWriteTokens, 50);
      expect(usage.uncachedInputTokens, 20);
      expect(const AiTokenUsage(cacheMissTokens: 20).cacheHitRatio, isNull);
      expect(
        api.usage({
          'usage': {'input_tokens': 20},
        }, 'claude-a')!.cacheHitTokens,
        isNull,
      );
    });

    test('metrics are bounded and store no prompts or credentials', () async {
      final store = AiRequestMetricsStore();
      addTearDown(store.dispose);
      final inner = _RecordingTransport(credentials, settings);
      final api = MeasuredAiChatTransport(inner, store);
      await api
          .streamComplete(
            modelId: 'gemini-3.8-flash',
            history: const [
              AiChatTurn(role: 'user', content: 'private source text'),
            ],
          )
          .toList();
      final row = (await store.list()).single;
      expect(row.usage.timeToFirstTokenMs, isNotNull);
      expect(row.usage.cacheHitTokens, isNull);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AiRequestMetricsStore.storageKey)!;
      expect(raw, isNot(contains('private source text')));
      expect(raw, isNot(contains('private-key')));
      for (var i = 0; i < 105; i++) {
        await store.add(row);
      }
      expect(await store.list(), hasLength(100));
    });
  });
}

class _RecordingTransport extends FakeGeminiChatService {
  _RecordingTransport(
    MemoryAiCredentialStore credentials,
    MemoryAiSettingsStore settings, {
    this.models,
  }) : super(credentials: credentials, settings: settings);
  final Future<List<AiSelectableModel>>? models;
  final requests = <List<AiChatTurn>>[];
  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) => models ?? super.listAvailableChatModels(timeout: timeout);
  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
    String? pocketChatId,
  }) async {
    requests.add(List.of(history));
    return AiChatCompletion(
      text:
          history.singleOrNull?.content.startsWith(
                'Return exactly [[CHAT_TITLE:',
              ) ==
              true
          ? '[[CHAT_TITLE: Gradient Descent]]'
          : 'Study answer',
      modelId: modelId,
    );
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
    String? pocketChatId,
  }) async* {
    yield const AiChatStreamEvent(textDelta: 'Study answer');
  }
}
