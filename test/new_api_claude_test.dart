import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/services/new_api_claude_service.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/new_api_claude_chat_service.dart';

void main() {
  late MemoryAiSettingsStore settings;
  late MemoryAiCredentialStore credentials;

  setUp(() async {
    settings = MemoryAiSettingsStore();
    credentials = MemoryAiCredentialStore();
    await settings.setNewApiBaseUrl('https://api.example.test/v1');
    await settings.setModelIdFor(AiProviderId.newApi, 'claude-example');
    await settings.setPrivacyConsentAccepted(true);
    await credentials.saveApiKeyFor(AiProviderId.newApi, 'secret-test-key');
  });

  test(
    'sends Anthropic Messages body and bearer auth to configured server',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.test/v1/messages');
        expect(request.followRedirects, false);
        expect(request.headers['authorization'], 'Bearer secret-test-key');
        expect(request.headers['anthropic-version'], '2023-06-01');
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], 'claude-example');
        expect(body['system'], 'Study assistant');
        expect(body['messages'], [
          {'role': 'user', 'content': 'Hello'},
        ]);
        expect(body['max_tokens'], 32);
        expect(body['stream'], false);
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'thinking', 'thinking': 'private'},
              {'type': 'text', 'text': 'Hi'},
            ],
            'usage': {
              'input_tokens': 12,
              'output_tokens': 2,
              'cache_read_input_tokens': 4,
            },
          }),
          200,
        );
      });
      final service = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );
      final result = await service.completeMessages(
        model: 'newapi:claude-example',
        messages: const [
          {'role': 'system', 'content': 'Study assistant'},
          {'role': 'user', 'content': 'Hello'},
        ],
        maxTokens: 32,
      );
      expect(result.text, 'Hi');
      expect(result.usage?.promptTokens, 16);
      expect(result.usage?.completionTokens, 2);
      expect(result.usage?.cacheHitTokens, 4);
      expect(result.usage?.provider, 'newApi');
    },
  );

  test('runs a study action using the selected New API model', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['system'], contains('Study Vault AI Assistant'));
      expect(body['messages'], isNotEmpty);
      expect(body['model'], 'claude-example');
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'A clear answer.'},
          ],
        }),
        200,
      );
    });
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      httpClient: client,
    );
    final result = await service.run(
      AiStudyRequest(
        action: AiStudyAction.explain,
        sourceText: 'Gradient descent',
        selection: AiExecutionSelection.resolve(
          provider: AiProviderId.newApi,
          requestedModelId: 'newapi:claude-example',
          action: AiStudyAction.explain,
        ),
      ),
    );
    expect((result as AiTextResult).markdown, contains('A clear answer.'));
  });

  test('does not send content without privacy consent', () async {
    await settings.setPrivacyConsentAccepted(false);
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      httpClient: MockClient((_) async => fail('No request expected')),
    );
    await expectLater(
      service.completeMessages(
        model: 'newapi:claude-example',
        messages: const [
          {'role': 'user', 'content': 'Hello'},
        ],
        maxTokens: 8,
      ),
      throwsA(isA<AiPrivacyNotAcceptedException>()),
    );
  });

  test('refuses non-HTTPS server URLs and missing model', () async {
    expect(
      () => normalizeNewApiBaseUrl('http://api.example.test'),
      throwsFormatException,
    );
    expect(
      () => normalizeNewApiBaseUrl('https://docs.newapi.pro'),
      throwsFormatException,
    );
    await settings.setModelIdFor(AiProviderId.newApi, '');
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
    );
    expect(await service.isConfigured, false);
    expect(
      () => service.modelName('newapi:'),
      throwsA(isA<AiNotConfiguredException>()),
    );
  });

  test('uses root base URL and classifies invalid key responses', () async {
    await settings.setNewApiBaseUrl('https://api.example.test/');
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.example.test/v1/messages');
      return http.Response('{"error":{"message":"unauthorized"}}', 401);
    });
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      httpClient: client,
    );
    await expectLater(
      service.completeMessages(
        model: 'newapi:claude-example',
        messages: const [
          {'role': 'user', 'content': 'Hello'},
        ],
        maxTokens: 8,
      ),
      throwsA(isA<AiInvalidKeyException>()),
    );
  });

  test(
    'loads exact model IDs from the configured server without leaking key',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.example.test/v1/models');
        expect(request.headers['authorization'], 'Bearer secret-test-key');
        expect(request.headers.containsKey('anthropic-version'), false);
        expect(request.followRedirects, false);
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'claude-example'},
              {'id': 'claude-other'},
              {'id': 'claude-example'},
            ],
          }),
          200,
        );
      });
      final service = NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );
      expect(await service.listAvailableModels(), [
        'claude-example',
        'claude-other',
      ]);
    },
  );

  test('distinguishes a missing endpoint from an unavailable model', () async {
    var calls = 0;
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          calls == 1
              ? 'Not Found'
              : '{"error":{"message":"model not available"}}',
          404,
        );
      }),
    );
    Future<void> check(Matcher matcher) async {
      await expectLater(
        service.completeMessages(
          model: 'newapi:claude-example',
          messages: const [
            {'role': 'user', 'content': 'Hi'},
          ],
          maxTokens: 8,
        ),
        throwsA(matcher),
      );
    }

    await check(
      isA<AiServerException>().having(
        (e) => e.message,
        'message',
        contains('server base URL'),
      ),
    );
    await check(
      isA<AiUnsupportedModelException>().having(
        (e) => e.message,
        'message',
        allOf(contains('claude-example'), isNot(contains('newapi:'))),
      ),
    );
  });

  test('chat transport sends history as Claude messages', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['messages'], [
        {'role': 'user', 'content': 'Explain this'},
        {'role': 'assistant', 'content': 'Earlier answer'},
        {'role': 'user', 'content': 'Go deeper'},
      ]);
      expect(body['system'], contains('Study Vault'));
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'Detailed answer'},
          ],
        }),
        200,
      );
    });
    final chat = NewApiClaudeChatService(
      settings: settings,
      service: NewApiClaudeService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      ),
    );
    final completion = await chat.complete(
      modelId: 'newapi:claude-example',
      history: const [
        AiChatTurn(role: AiChatRole.user, content: 'Explain this'),
        AiChatTurn(role: AiChatRole.assistant, content: 'Earlier answer'),
        AiChatTurn(role: AiChatRole.user, content: 'Go deeper'),
      ],
    );
    expect(completion.text, 'Detailed answer');
  });

  test('streams only text deltas, ignoring thinking blocks', () async {
    final client = MockClient((request) async {
      expect(jsonDecode(request.body)['stream'], true);
      return http.Response(
        'data: {"type":"message_start","message":{"usage":{"input_tokens":5}}}\n\n'
        'data: {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"secret"}}\n\n'
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}\n\n'
        'data: {"type":"message_delta","usage":{"output_tokens":2}}\n\n',
        200,
      );
    });
    final service = NewApiClaudeService(
      credentials: credentials,
      settings: settings,
      httpClient: client,
    );
    final events = await service
        .streamMessages(
          model: 'newapi:claude-example',
          messages: const [
            {'role': 'user', 'content': 'Hi'},
          ],
        )
        .toList();
    expect(events.where((e) => e.text != null).map((e) => e.text), ['Hello']);
    expect(events.last.usage?.completionTokens, 2);
  });
}
