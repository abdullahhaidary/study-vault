import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_endpoint_profile_repository.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_endpoint_catalog.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_endpoint_profile.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_model_ref.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/gemini_model_registry.dart';
import 'package:study_vault/features/ai_assistant/services/new_api_claude_service.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';
import 'package:study_vault/features/ai_generation_queue/data/ai_generation_job_repository.dart';
import 'package:study_vault/features/ai_generation_queue/domain/ai_generation_models.dart';
import 'package:study_vault/features/ai_generation_queue/services/ai_generation_coordinator.dart';
import 'package:study_vault/features/ai_generation_queue/services/ai_generation_runner.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';

void main() {
  late MemoryAiSettingsStore settings;
  late MemoryAiCredentialStore credentials;
  late MemoryAiEndpointCatalogStore store;
  late AiEndpointProfileRepository profiles;

  setUp(() {
    settings = MemoryAiSettingsStore();
    credentials = MemoryAiCredentialStore();
    store = MemoryAiEndpointCatalogStore();
    profiles = AiEndpointProfileRepository(
      store: store,
      settings: settings,
      credentials: credentials,
    );
  });

  AiEndpointProfileRepository repoWith(DateTime Function() clock) {
    return AiEndpointProfileRepository(
      store: store,
      settings: settings,
      credentials: credentials,
      clock: clock,
    );
  }

  test('profiles keep separate urls, keys, models, and defaults', () async {
    final personal = await profiles.create(
      name: 'Personal New API',
      baseUrl: 'https://personal.example.com/v1/',
      apiKey: 'personal-secret-key-aaaa',
      defaultModelId: 'claude-a',
    );
    final university = await profiles.create(
      name: 'University Server',
      baseUrl: 'https://ai.university.example',
      apiKey: 'university-secret-key-bbbb',
      defaultModelId: 'campus-model',
    );
    await profiles.cacheModels(
      id: personal.id,
      modelIds: ['claude-a', 'claude-a', 'claude-b'],
    );
    await profiles.update(
      id: university.id,
      name: 'University Server',
      defaultModelId: 'campus-pro',
    );

    final saved = await profiles.list();
    expect(saved, hasLength(2));
    expect(saved[0].baseUrl, 'https://personal.example.com/v1');
    expect(saved[0].defaultModelId, 'claude-a');
    expect(saved[0].cachedModelIds, ['claude-a', 'claude-b']);
    expect(saved[0].keySuffix, 'aaaa');
    expect(
      await credentials.readEndpointKey(personal.id),
      'personal-secret-key-aaaa',
    );
    expect(saved[1].host, 'ai.university.example');
    expect((await profiles.find(university.id))!.defaultModelId, 'campus-pro');
    expect(
      await credentials.readEndpointKey(university.id),
      'university-secret-key-bbbb',
    );

    await profiles.update(id: personal.id, name: 'Personal New API');
    expect(
      await credentials.readEndpointKey(personal.id),
      'personal-secret-key-aaaa',
    );
    await profiles.update(
      id: personal.id,
      replacementApiKey: 'replaced-secret-key-cccc',
    );
    expect(
      await credentials.readEndpointKey(personal.id),
      'replaced-secret-key-cccc',
    );
    expect((await profiles.find(personal.id))!.keySuffix, 'cccc');

    await profiles.delete(personal.id);
    expect(await profiles.find(personal.id), isNull);
    expect(await credentials.hasEndpointKey(personal.id), isFalse);
    expect(await profiles.find(university.id), isNotNull);
  });

  test('metadata and profile objects never contain the full key', () async {
    const secret = 'super-secret-profile-key-9999';
    await profiles.create(
      name: 'Personal New API',
      baseUrl: 'https://personal.example.com/v1',
      apiKey: secret,
      defaultModelId: 'claude-a',
    );
    final metadata = await profiles.metadataJson();
    final profile = (await profiles.list()).single;
    expect(metadata.contains(secret), isFalse);
    expect(jsonEncode(profile.toJson()).contains(secret), isFalse);
    expect(profile.keySuffix, '9999');
    expect(metadata, contains('9999'));
  });

  test('the same model id from two profiles stays two picker rows', () async {
    final first = await profiles.create(
      name: 'Personal New API',
      baseUrl: 'https://personal.example.com/v1',
      apiKey: 'personal-secret-key-aaaa',
      defaultModelId: 'shared-model',
    );
    final second = await profiles.create(
      name: 'University Server',
      baseUrl: 'https://ai.university.example/v1',
      apiKey: 'university-secret-key-bbbb',
      defaultModelId: 'shared-model',
    );
    await profiles.cacheModels(id: first.id, modelIds: ['shared-model']);
    await profiles.cacheModels(id: second.id, modelIds: ['shared-model']);
    final rows = selectableModelsForEndpointProfiles(await profiles.list());
    expect(rows.map((row) => row.modelRef), [
      EndpointAiModelRef(profileId: first.id, modelId: 'shared-model'),
      EndpointAiModelRef(profileId: second.id, modelId: 'shared-model'),
    ]);
    expect(rows.map((row) => row.sectionLabel), [
      'Personal New API',
      'University Server',
    ]);
    expect(rows[0].id, isNot(rows[1].id));
  });

  test(
    'refresh uses that profile url and key and keeps cache on failure',
    () async {
      final personal = await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'claude-a',
      );
      final university = await profiles.create(
        name: 'University Server',
        baseUrl: 'https://ai.university.example/v1',
        apiKey: 'university-secret-key-bbbb',
        defaultModelId: 'campus-model',
      );
      await profiles.cacheModels(id: personal.id, modelIds: ['claude-a']);
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://ai.university.example/v1/models',
        );
        expect(
          request.headers['authorization'],
          'Bearer university-secret-key-bbbb',
        );
        return http.Response('nope', 500);
      });
      final service = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        profiles: profiles,
        httpClient: client,
      );
      await expectLater(
        service.refreshCachedModels(university.id),
        throwsA(isA<AiServerException>()),
      );
      expect((await profiles.find(personal.id))!.cachedModelIds, ['claude-a']);
      expect((await profiles.find(university.id))!.cachedModelIds, isEmpty);
      expect(
        (await profiles.find(university.id))!.connectionStatus,
        AiEndpointConnectionStatus.failed,
      );

      final success = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        profiles: profiles,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'personal.example.com');
          expect(
            request.headers['authorization'],
            'Bearer personal-secret-key-aaaa',
          );
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'claude-b'},
                {'id': 'claude-a'},
                {'id': 'claude-b'},
              ],
            }),
            200,
          );
        }),
      );
      expect(await success.refreshCachedModels(personal.id), [
        'claude-a',
        'claude-b',
      ]);
    },
  );

  test(
    'global default loads and a temporary selection does not replace it',
    () async {
      final personal = await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'claude-a',
        makeGlobalDefault: true,
      );
      await profiles.create(
        name: 'Backup Server',
        baseUrl: 'https://backup.example.com/v1',
        apiKey: 'backup-secret-key-dddd',
        defaultModelId: 'backup-model',
      );
      final global = await AiExecutionSelection.fromGlobal(
        settings,
        action: null,
      );
      expect(global.provider, AiProviderId.newApi);
      expect(global.endpointProfileId, personal.id);
      expect(global.resolvedModelId, 'newapi:claude-a');

      final temporary = AiExecutionSelection.fromModelRef(
        EndpointAiModelRef(profileId: 'unused', modelId: 'other-model'),
      );
      expect(temporary.endpointProfileId, 'unused');
      expect(
        (await AiExecutionSelection.fromGlobal(
          settings,
          action: null,
        )).endpointProfileId,
        personal.id,
      );
      expect(await settings.getProvider(), AiProviderId.newApi);
    },
  );

  test(
    'requests keep the selected profile after the global default changes',
    () async {
      final personal = await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'shared-model',
        makeGlobalDefault: true,
      );
      final backup = await profiles.create(
        name: 'Backup Server',
        baseUrl: 'https://backup.example.com/v1',
        apiKey: 'backup-secret-key-dddd',
        defaultModelId: 'shared-model',
      );
      await settings.setGlobalModelRef(
        EndpointAiModelRef(profileId: backup.id, modelId: 'shared-model'),
      );
      final seen = <String>[];
      final service = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        profiles: profiles,
        httpClient: MockClient((request) async {
          seen.add('${request.url.host}|${request.headers['authorization']}');
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
            }),
            200,
          );
        }),
      );
      await settings.setPrivacyConsentAccepted(true);
      await service.completeMessages(
        profileId: personal.id,
        model: 'newapi:shared-model',
        messages: const [
          {'role': 'user', 'content': 'Hello'},
        ],
        maxTokens: 16,
      );
      expect(seen, ['personal.example.com|Bearer personal-secret-key-aaaa']);
      expect((await settings.getGlobalModelRef()).endpointProfileId, backup.id);
    },
  );

  test('legacy New API configuration migrates once', () async {
    await settings.setNewApiBaseUrl('https://legacy.example.com/v1/');
    await settings.setModelIdFor(AiProviderId.newApi, 'legacy-model');
    await settings.setProvider(AiProviderId.newApi);
    await credentials.saveApiKeyFor(
      AiProviderId.newApi,
      'legacy-secret-key-zzzz',
    );
    await profiles.ensureMigrated();
    await profiles.ensureMigrated();
    final saved = await profiles.list();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'New API');
    expect(saved.single.baseUrl, 'https://legacy.example.com/v1');
    expect(saved.single.defaultModelId, 'legacy-model');
    expect(await profiles.legacyProfileId(), saved.single.id);
    expect(
      await credentials.readEndpointKey(saved.single.id),
      'legacy-secret-key-zzzz',
    );
    expect(await credentials.hasApiKeyFor(AiProviderId.newApi), isFalse);
    final global = await settings.getGlobalModelRef();
    expect(global, isA<EndpointAiModelRef>());
    expect(global.endpointProfileId, saved.single.id);
    expect(global.bareModelId, 'legacy-model');
    final legacy = AiModelRef.parse('newapi:legacy-model');
    final bound = await profiles.bindLegacy(legacy);
    expect(bound.endpointProfileId, saved.single.id);
  });

  test(
    'gemini and deepseek global defaults stay independent of profiles',
    () async {
      await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'claude-a',
      );
      final gemini = await AiExecutionSelection.fromGlobal(
        settings,
        action: null,
      );
      expect(gemini.provider, AiProviderId.gemini);
      expect(gemini.endpointProfileId, isNull);
      expect(gemini.resolvedModelId, GeminiModelRegistry.defaultModelId);
      await settings.setGlobalModelRef(
        BuiltinDeepSeekModelRef('deepseek-flash'),
      );
      final deepseek = await AiExecutionSelection.fromGlobal(
        settings,
        action: null,
      );
      expect(deepseek.provider, AiProviderId.deepseek);
      expect(deepseek.endpointProfileId, isNull);
      expect(AiModels.isKnown(deepseek.resolvedModelId), isTrue);
    },
  );

  test('vision requests disable custom text-only profiles', () async {
    await profiles.create(
      name: 'Personal New API',
      baseUrl: 'https://personal.example.com/v1',
      apiKey: 'personal-secret-key-aaaa',
      defaultModelId: 'claude-a',
    );
    await profiles.cacheModels(
      id: (await profiles.list()).single.id,
      modelIds: ['claude-a'],
    );
    final rows = selectableModelsForEndpointProfiles(
      await profiles.list(),
      visionOnly: true,
    );
    expect(rows.single.enabled, isFalse);
    expect(rows.single.disabledReason, contains('Gemini'));
    expect(rows.single.supportsVision, isFalse);
  });

  test('urls are normalized and unsafe urls are rejected', () {
    expect(
      normalizeNewApiBaseUrl('https://personal.example.com/v1/'),
      'https://personal.example.com/v1',
    );
    expect(
      normalizeNewApiBaseUrl('https://personal.example.com/'),
      'https://personal.example.com',
    );
    expect(
      normalizeNewApiBaseUrl('http://localhost:8080/v1/'),
      'http://localhost:8080/v1',
    );
    expect(normalizeNewApiBaseUrl('http://127.0.0.1:9'), 'http://127.0.0.1:9');
    expect(
      () => normalizeNewApiBaseUrl('http://api.example.test'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://user:pass@host.example/v1'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://host.example/v1?token=1'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://host.example/v1#frag'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://host.example/v1/messages'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://host.example/models'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://docs.newapi.pro/guide'),
      throwsFormatException,
    );
  });

  test('http loopback profiles are allowed and marked insecure', () async {
    final local = await profiles.create(
      name: 'Local',
      baseUrl: 'http://localhost:8080',
      apiKey: 'local-secret-key-llll',
      defaultModelId: 'dev-model',
    );
    expect(local.warnsInsecureHttp, isTrue);
    expect(local.baseUrl, 'http://localhost:8080');
  });

  test(
    'queued jobs keep their profile and deleted profiles need configuration',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final jobs = AiGenerationJobRepository(db);
      final personal = await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'claude-a',
      );
      final seen = <String?>[];
      final coordinator = AiGenerationCoordinator(
        repository: jobs,
        runner: _RecordingRunner(seen),
        delay: (_) async {},
      );
      addTearDown(coordinator.dispose);
      await coordinator.enqueue(
        AiGenerationEnqueue(
          materialId: 'material-1',
          title: 'Lesson',
          filePath: '/tmp/lesson.pdf',
          type: PdfAiMaterialType.summary,
          provider: AiProviderId.newApi.storageValue,
          requestedModelId: 'newapi:claude-a',
          resolvedModelId: 'newapi:claude-a',
          endpointProfileId: personal.id,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, [personal.id]);
      await settings.setGlobalModelRef(
        BuiltinGeminiModelRef(GeminiModelRegistry.defaultModelId),
      );
      expect(coordinator.current.single.endpointProfileId, personal.id);

      final queued = coordinator.current.single.copyWith(
        status: AiGenerationJobStatus.queued,
      );
      await jobs.save(queued);
      await jobs.markEndpointProfileUnavailable(personal.id, DateTime.now());
      final marked = await jobs.byId(queued.id);
      expect(marked!.status, AiGenerationJobStatus.configurationRequired);
      expect(marked.endpointProfileId, personal.id);
      expect(marked.needsProfileReplacement, isTrue);
    },
  );

  test(
    'chat stores the profile and blocks send after that profile is deleted',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await credentials.saveApiKeyFor(AiProviderId.gemini, 'gemini-test-key');
      await settings.setPrivacyConsentAccepted(true);
      final personal = await profiles.create(
        name: 'Personal New API',
        baseUrl: 'https://personal.example.com/v1',
        apiKey: 'personal-secret-key-aaaa',
        defaultModelId: 'claude-a',
      );
      final service = AiChatService(
        db: db,
        settings: settings,
        profiles: profiles,
        gemini: FakeGeminiChatService(
          credentials: credentials,
          settings: settings,
          reply: 'Stored answer',
        ),
      );
      final ref = EndpointAiModelRef(
        profileId: personal.id,
        modelId: 'claude-a',
      );
      final chat = await service.createChat(modelId: ref.storageValue);
      expect(chat.modelId, ref.storageValue);
      expect(chat.modelId.contains('personal-secret-key-aaaa'), isFalse);
      await service
          .streamSend(chatId: chat.id, userText: 'Hello')
          .drain<void>();
      final beforeDelete = await db.getAiChatMessages(chat.id);
      expect(beforeDelete, isNotEmpty);

      await profiles.delete(personal.id);
      final stillThere = await db.getAiChatById(chat.id);
      expect(stillThere!.modelId, ref.storageValue);
      expect(await db.getAiChatMessages(chat.id), isNotEmpty);
      expect(
        await profiles.isAvailable(AiModelRef.parse(stillThere.modelId)),
        isFalse,
      );
      expect(
        service.streamSend(chatId: chat.id, userText: 'Again'),
        emitsError(isA<AiProfileUnavailableException>()),
      );
    },
  );

  test(
    'a missing profile is not silently replaced by the global default',
    () async {
      final backup = await profiles.create(
        name: 'Backup Server',
        baseUrl: 'https://backup.example.com/v1',
        apiKey: 'backup-secret-key-dddd',
        defaultModelId: 'backup-model',
        makeGlobalDefault: true,
      );
      final service = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        profiles: profiles,
        httpClient: MockClient((_) async => fail('request must not be sent')),
      );
      await settings.setPrivacyConsentAccepted(true);
      await expectLater(
        service.completeMessages(
          profileId: '11111111-1111-1111-1111-111111111111',
          model: 'newapi:shared-model',
          messages: const [
            {'role': 'user', 'content': 'Hello'},
          ],
          maxTokens: 8,
        ),
        throwsA(isA<AiProfileUnavailableException>()),
      );
      expect((await settings.getGlobalModelRef()).endpointProfileId, backup.id);
    },
  );

  test('failed refresh preserves an existing cached list', () async {
    var now = DateTime.utc(2026, 1, 1);
    profiles = repoWith(() => now);
    final personal = await profiles.create(
      name: 'Personal New API',
      baseUrl: 'https://personal.example.com/v1',
      apiKey: 'personal-secret-key-aaaa',
      defaultModelId: 'claude-a',
    );
    await profiles.cacheModels(
      id: personal.id,
      modelIds: ['claude-a', 'claude-b'],
    );
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      profiles: profiles,
      httpClient: MockClient(
        (_) async => http.Response('{"error":{"message":"down"}}', 503),
      ),
    );
    await expectLater(
      service.refreshCachedModels(personal.id),
      throwsA(isA<AiException>()),
    );
    final saved = await profiles.find(personal.id);
    expect(saved!.cachedModelIds, ['claude-a', 'claude-b']);
    expect(saved.modelsRefreshedAt?.isAtSameMomentAs(now), isTrue);
  });
}

class _RecordingRunner implements AiGenerationRunner {
  _RecordingRunner(this.seen);

  final List<String?> seen;

  @override
  Future<AiGenerationRunResult> run(
    AiGenerationJob job,
    AiGenerationRunControl control,
  ) async {
    seen.add(job.endpointProfileId);
    return const AiGenerationRunSuccess(resultMaterialId: 'result-1');
  }

  @override
  Future<String> savePartial(AiGenerationJob job) async => 'result-1';
}
