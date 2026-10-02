import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/deepseek_model_registry.dart';
import 'package:study_vault/features/ai_assistant/services/deepseek_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/routing_ai_service.dart';

void main() {
  group('DeepSeekModelRegistry', () {
    test('normalizes aliases and unknown ids', () {
      expect(DeepSeekModelRegistry.normalize(null), 'deepseek-flash');
      expect(
        DeepSeekModelRegistry.normalize('deepseek-v4-flash'),
        'deepseek-flash',
      );
      expect(
        DeepSeekModelRegistry.normalize('deepseek-v4-pro'),
        'deepseek-v4-pro',
      );
      expect(DeepSeekModelRegistry.normalize('unknown'), 'deepseek-flash');
    });

    test('auto routing prefers pro for heavy actions', () {
      expect(
        resolveActiveModelId(
          provider: AiProviderId.deepseek,
          storedModelId: DeepSeekModelIds.auto,
          action: AiStudyAction.explain,
        ),
        'deepseek-flash',
      );
      expect(
        resolveActiveModelId(
          provider: AiProviderId.deepseek,
          storedModelId: DeepSeekModelIds.auto,
          action: AiStudyAction.generateQuestions,
        ),
        'deepseek-v4-pro',
      );
    });
  });

  group('AiSettingsStore provider persistence', () {
    test('keeps per-provider models and thinking mode', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setModelId(DeepSeekModelRegistry.v4Pro);
      await settings.setThinkingMode(AiThinkingMode.high);

      expect(await settings.getProvider(), AiProviderId.deepseek);
      expect(await settings.getModelId(), DeepSeekModelRegistry.v4Pro);
      expect(await settings.getThinkingMode(), AiThinkingMode.high);

      await settings.setProvider(AiProviderId.gemini);
      expect(await settings.getModelId(), isNot(DeepSeekModelRegistry.v4Pro));
      await settings.setProvider(AiProviderId.deepseek);
      expect(await settings.getModelId(), DeepSeekModelRegistry.v4Pro);
    });
  });

  group('RoutingAiService', () {
    test('routes to selected provider service', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setPrivacyConsentAccepted(true);

      var geminiCalls = 0;
      var deepseekCalls = 0;

      final router = RoutingAiService(
        settings: settings,
        gemini: FakeAiService(
          handler: (request) async {
            geminiCalls++;
            return const AiTextResult(markdown: 'gemini');
          },
        ),
        deepseek: FakeAiService(
          handler: (request) async {
            deepseekCalls++;
            return const AiTextResult(markdown: 'deepseek');
          },
        ),
      );

      final result = await router.run(
        const AiStudyRequest(
          action: AiStudyAction.explain,
          sourceText: 'Gradient descent',
        ),
      );
      expect(result, isA<AiTextResult>());
      expect((result as AiTextResult).markdown, 'deepseek');
      expect(deepseekCalls, 1);
      expect(geminiCalls, 0);
    });
  });

  group('DeepSeekAiService HTTP', () {
    test('sends chat completions with bearer auth and model', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'OK',
                  'reasoning_content': 'secret thoughts',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.deepseek, 'sk-test-key');
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setModelIdFor(
        AiProviderId.deepseek,
        DeepSeekModelRegistry.flash,
      );
      await settings.setPrivacyConsentAccepted(true);
      await settings.setThinkingMode(AiThinkingMode.low);

      final service = DeepSeekAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );

      await service.testConnection();

      expect(seen, isNotNull);
      expect(seen!.url.toString(), 'https://api.deepseek.com/chat/completions');
      expect(seen!.headers['Authorization'], 'Bearer sk-test-key');
      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-flash');
      expect(body['stream'], isFalse);
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['reasoning_effort'], 'low');
    });

    test('maps 401 to invalid key and never retries auth failures', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.deepseek, 'bad');
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setPrivacyConsentAccepted(true);

      final service = DeepSeekAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );

      await expectLater(
        service.testConnection(),
        throwsA(isA<AiInvalidKeyException>()),
      );
      expect(calls, 1);
    });

    test(
      'parses structured JSON flashcards without exposing reasoning',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content':
                        '{"cards":[{"front":"Q1","back":"A1"},{"front":"Q2","back":"A2"}]}',
                    'reasoning_content': 'do not show',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final credentials = MemoryAiCredentialStore();
        await credentials.saveApiKeyFor(AiProviderId.deepseek, 'sk-test');
        final settings = MemoryAiSettingsStore();
        await settings.setProvider(AiProviderId.deepseek);
        await settings.setPrivacyConsentAccepted(true);

        final service = DeepSeekAiService(
          credentials: credentials,
          settings: settings,
          httpClient: client,
        );

        final result = await service.run(
          const AiStudyRequest(
            action: AiStudyAction.generateFlashcards,
            sourceText: 'Gradient descent minimizes a cost function.',
            flashcardCount: 2,
          ),
        );

        expect(result, isA<AiFlashcardsResult>());
        final cards = (result as AiFlashcardsResult).cards;
        expect(cards, hasLength(2));
        expect(cards.first.front, 'Q1');
      },
    );

    test('maps insufficient balance to quota error', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Insufficient Balance'},
          }),
          402,
        );
      });

      final credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.deepseek, 'sk-test');
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setPrivacyConsentAccepted(true);

      final service = DeepSeekAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );

      await expectLater(
        service.testConnection(),
        throwsA(isA<AiQuotaException>()),
      );
    });
  });

  group('provider capabilities', () {
    test('DeepSeek reports thinking and streaming', () {
      final caps = AiProviderCapabilities.forProvider(AiProviderId.deepseek);
      expect(caps.thinking, isTrue);
      expect(caps.streaming, isTrue);
      expect(caps.structuredJson, isTrue);
    });
  });
}
