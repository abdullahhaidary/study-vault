import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_model_ref.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/pocket_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/pocket_client.dart';
import 'package:study_vault/features/ai_assistant/services/routing_ai_service.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/pocket_chat_service.dart';

void main() {
  test('pocket model ids stay distinct from Gemini', () {
    final ref = AiModelRef.parse('sv1:pocket:claude');
    expect(ref, isA<PocketModelRef>());
    expect(ref.provider, AiProviderId.pocket);
    expect(ref.storageValue, 'sv1:pocket:claude');
    expect(AiProviderIdX.fromModelId(ref.storageValue), AiProviderId.pocket);
    expect(AiModels.chatDisplayName(ref.storageValue), 'Pocket · Claude');
    final account = AiModelRef.parse('sv1:pocket:chatgpt:work');
    expect(account, isA<PocketModelRef>());
    expect((account as PocketModelRef).accountId, 'work');
    expect(account.storageValue, 'sv1:pocket:chatgpt:work');
    expect(account.chatLabel, 'Pocket · ChatGPT · work');
    expect(
      () => normalizePocketBaseUrl('https://example.com'),
      throwsFormatException,
    );
    expect(normalizePocketBaseUrl('127.0.0.1:9000'), 'http://127.0.0.1:9000');
  });

  test('study action posts a new Pocket chat and keeps the reply', () async {
    http.Request? seen;
    final settings = MemoryAiSettingsStore();
    await settings.setPrivacyConsentAccepted(true);
    await settings.setProvider(AiProviderId.pocket);
    final client = PocketClient(
      settings: settings,
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'id': 'chatcmpl_test',
            'object': 'chat.completion',
            'model': 'chatgpt',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'A tree has one root.',
                },
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
        );
      }),
    );
    final service = PocketAiService(settings: settings, client: client);
    final result = await service.run(
      AiStudyRequest(
        selection: AiExecutionSelection.resolve(
          provider: AiProviderId.pocket,
          requestedModelId: 'sv1:pocket:chatgpt',
          action: AiStudyAction.explain,
        ),
        action: AiStudyAction.explain,
        sourceText: 'A tree connects nodes with edges.',
      ),
    );

    expect(result, isA<AiTextResult>());
    expect((result as AiTextResult).markdown, 'A tree has one root.');
    final body = jsonDecode(seen!.body) as Map<String, dynamic>;
    expect(seen!.url.path, '/chat');
    expect(body['app'], 'chatgpt');
    expect(body['new_chat'], isTrue);
    expect(body['message'], contains('A tree connects nodes with edges.'));
  });

  test('page images stay on Pocket instead of the Gemini API', () async {
    final settings = MemoryAiSettingsStore();
    await settings.setPrivacyConsentAccepted(true);
    var pocketCalls = 0;
    final router = RoutingAiService(
      settings: settings,
      gemini: FakeAiService(
        handler: (_) async => const AiTextResult(markdown: 'gemini'),
      ),
      deepseek: FakeAiService(
        handler: (_) async => const AiTextResult(markdown: 'deepseek'),
      ),
      pocket: PocketAiService(
        settings: settings,
        client: PocketClient(
          settings: settings,
          httpClient: MockClient((request) async {
            pocketCalls++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['files'], isA<List>());
            expect(
              (body['files'] as List).single,
              contains('study-vault-pocket-'),
            );
            return http.Response(
              jsonEncode({
                'id': 'chatcmpl_test',
                'object': 'chat.completion',
                'model': 'claude',
                'choices': [
                  {
                    'index': 0,
                    'message': {'role': 'assistant', 'content': 'diagram'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
              200,
            );
          }),
        ),
      ),
    );

    final result = await router.run(
      AiStudyRequest(
        selection: AiExecutionSelection.resolve(
          provider: AiProviderId.pocket,
          requestedModelId: 'claude',
          action: AiStudyAction.explain,
        ),
        action: AiStudyAction.explain,
        sourceText: 'page',
        pageSendMode: AiPageSendMode.image,
        image: AiStudyImage(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          mimeType: 'image/png',
          pageNumber: 1,
        ),
      ),
    );

    expect((result as AiTextResult).markdown, 'diagram');
    expect(pocketCalls, 1);
  });

  test('chat history is one Pocket message', () async {
    http.Request? seen;
    final settings = MemoryAiSettingsStore();
    final chat = PocketChatService(
      settings: settings,
      client: PocketClient(
        settings: settings,
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'id': 'chatcmpl_test',
              'object': 'chat.completion',
              'model': 'gemini',
              'choices': [
                {
                  'index': 0,
                  'message': {'role': 'assistant', 'content': 'pong'},
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
          );
        }),
      ),
    );
    final done = await chat.complete(
      modelId: 'sv1:pocket:gemini',
      history: const [
        AiChatTurn(role: AiChatRole.user, content: 'ping'),
        AiChatTurn(role: AiChatRole.assistant, content: 'pong earlier'),
        AiChatTurn(role: AiChatRole.user, content: 'again'),
      ],
    );
    final body = jsonDecode(seen!.body) as Map<String, dynamic>;
    expect(done.text, 'pong');
    expect(body['app'], 'gemini');
    expect(body['message'], contains('User:\nping'));
    expect(body['message'], contains('Assistant:\npong earlier'));
    expect(body['message'], contains('User:\nagain'));
  });

  test('a stopped Pocket server is reported clearly', () async {
    final settings = MemoryAiSettingsStore();
    final client = PocketClient(
      settings: settings,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Timed out waiting for ChatGPT\'s reply.',
              'type': 'server_error',
            },
          }),
          502,
        );
      }),
    );
    await expectLater(
      client.send(modelId: 'chatgpt', message: 'hi'),
      throwsA(isA<AiTimeoutException>()),
    );
  });

  test(
    'a completion stream opens, appends deltas, and closes on stop',
    () async {
      const sse = '''
: pocket

data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"claude","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"claude","choices":[{"index":0,"delta":{"content":"1\\n2\\n3\\n"},"finish_reason":null}]}

data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"claude","choices":[{"index":0,"delta":{"content":"4\\n5"},"finish_reason":null}]}

data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"claude","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''';
      final settings = MemoryAiSettingsStore();
      final client = PocketClient(
        settings: settings,
        httpClient: MockClient((request) async {
          expect(request.headers['accept'], 'text/event-stream');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stream'], isTrue);
          expect(body['app'], 'claude');
          expect(body['new_chat'], isTrue);
          expect(body.containsKey('chat_id'), isFalse);
          return http.Response(
            sse,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      final chat = PocketChatService(settings: settings, client: client);
      final events = await chat
          .streamComplete(
            modelId: 'sv1:pocket:claude',
            history: const [
              AiChatTurn(role: AiChatRole.user, content: 'count'),
            ],
          )
          .toList();
      final text = events.map((event) => event.textDelta ?? '').join();
      expect(text, '1\n2\n3\n4\n5');
      expect(events.last.usage, isNotNull);
    },
  );

  test(
    'a chat id continues that browser chat with only the new message',
    () async {
      http.Request? seen;
      const sse = '''
data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"chatgpt","chat_id":"chat_0123456789abcdef","choices":[{"index":0,"delta":{"content":"same"},"finish_reason":null}]}

data: {"id":"chatcmpl_test","object":"chat.completion.chunk","model":"chatgpt","chat_id":"chat_0123456789abcdef","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''';
      final settings = MemoryAiSettingsStore();
      final client = PocketClient(
        settings: settings,
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            sse,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      final chat = PocketChatService(settings: settings, client: client);
      final events = await chat
          .streamComplete(
            modelId: 'sv1:pocket:chatgpt',
            pocketChatId: 'chat_0123456789abcdef',
            history: const [
              AiChatTurn(role: AiChatRole.user, content: 'first'),
              AiChatTurn(role: AiChatRole.assistant, content: 'pong'),
              AiChatTurn(role: AiChatRole.user, content: 'Say it again.'),
            ],
          )
          .toList();
      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      expect(body['chat_id'], 'chat_0123456789abcdef');
      expect(body.containsKey('new_chat'), isFalse);
      expect(body['message'], 'Say it again.');
      expect(events.last.pocketChatId, 'chat_0123456789abcdef');
    },
  );

  test('browser chat history is listed from Pocket', () async {
    final settings = MemoryAiSettingsStore();
    final client = PocketClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/chats');
        expect(request.url.queryParameters['app'], 'chatgpt');
        return http.Response(
          jsonEncode({
            'chats': [
              {
                'id': 'chat_0123456789abcdef',
                'app': 'chatgpt',
                'title': 'Pong',
                'account': 'default',
              },
            ],
          }),
          200,
        );
      }),
    );
    final chats = await client.listChats(app: 'chatgpt');
    expect(chats, hasLength(1));
    expect(chats.single.title, 'Pong');
    expect(chats.single.id, 'chat_0123456789abcdef');
  });
}
