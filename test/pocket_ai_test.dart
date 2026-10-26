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
          jsonEncode({'reply': 'A tree has one root.', 'images': []}),
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
            return http.Response(jsonEncode({'reply': 'diagram'}), 200);
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
          return http.Response(jsonEncode({'reply': 'pong'}), 200);
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
          jsonEncode({'error': 'Timed out waiting for ChatGPT\'s reply.'}),
          502,
        );
      }),
    );
    await expectLater(
      client.send(modelId: 'chatgpt', message: 'hi'),
      throwsA(isA<AiTimeoutException>()),
    );
  });
}
