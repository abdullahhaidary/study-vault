import 'dart:convert';
import 'dart:typed_data';

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
import 'package:study_vault/features/ai_assistant/domain/deepseek_pricing_period.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_token_usage.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/deepseek_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/routing_ai_service.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/services/deepseek_chat_service.dart';

void main() {
  group('DeepSeekPricingSchedule', () {
    test('weekday UTC peak windows', () {
      // Wednesday 2026-04-01
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 1, 0)),
        DeepSeekPricingPeriod.peak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 3, 59)),
        DeepSeekPricingPeriod.peak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 4, 0)),
        DeepSeekPricingPeriod.offPeak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 6, 0)),
        DeepSeekPricingPeriod.peak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 9, 59)),
        DeepSeekPricingPeriod.peak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 10, 0)),
        DeepSeekPricingPeriod.offPeak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 12, 0)),
        DeepSeekPricingPeriod.offPeak,
      );
    });

    test('weekends are always off-peak', () {
      // Saturday / Sunday during weekday peak UTC hours
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 4, 2, 0)),
        DeepSeekPricingPeriod.offPeak,
      );
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 5, 7, 0)),
        DeepSeekPricingPeriod.offPeak,
      );
    });

    test('Afghanistan local peak maps to UTC windows', () {
      // AFT = UTC+4:30 → 05:30 AFT = 01:00 UTC (peak start)
      // Use explicit UTC equivalents of Afghanistan windows.
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 1, 0)),
        DeepSeekPricingPeriod.peak,
      ); // 5:30 AM AFT
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 4, 0)),
        DeepSeekPricingPeriod.offPeak,
      ); // 8:30 AM AFT
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 6, 0)),
        DeepSeekPricingPeriod.peak,
      ); // 10:30 AM AFT
      expect(
        DeepSeekPricingSchedule.forUtc(DateTime.utc(2026, 4, 1, 10, 0)),
        DeepSeekPricingPeriod.offPeak,
      ); // 2:30 PM AFT
    });
  });

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

    test('chat labels DeepSeek models instead of unavailable', () {
      expect(AiModels.isKnown(DeepSeekModelRegistry.flash), isTrue);
      expect(AiModels.isKnown(DeepSeekModelIds.auto), isTrue);
      expect(
        AiModels.chatDisplayName(DeepSeekModelRegistry.flash),
        'DeepSeek Flash',
      );
      expect(AiModels.chatDisplayName(DeepSeekModelIds.auto), 'DeepSeek Auto');
      expect(
        AiModels.chatDisplayName('totally-gone-model'),
        'Previous model unavailable',
      );
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

    test(
      'routes page images to Gemini even when DeepSeek is selected',
      () async {
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
              expect(request.hasPageImage, isTrue);
              return const AiTextResult(markdown: 'gemini-vision');
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
          AiStudyRequest(
            action: AiStudyAction.explain,
            sourceText: 'PDF page 2 (image attached)',
            pageSendMode: AiPageSendMode.image,
            image: AiStudyImage(
              bytes: Uint8List.fromList(const [1, 2, 3, 4]),
              mimeType: 'image/jpeg',
              pageNumber: 2,
            ),
          ),
        );
        expect(result, isA<AiTextResult>());
        expect((result as AiTextResult).markdown, 'gemini-vision');
        expect(geminiCalls, 1);
        expect(deepseekCalls, 0);
      },
    );
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

  group('AiTokenUsage', () {
    test('reads official cache hit/miss fields and ratio', () {
      final usage = AiTokenUsage.fromProviderResponse(
        {
          'usage': {
            'prompt_tokens': 14210,
            'completion_tokens': 1025,
            'total_tokens': 15235,
            'prompt_cache_hit_tokens': 13400,
            'prompt_cache_miss_tokens': 810,
          },
        },
        model: 'deepseek-flash',
        durationMs: 412,
      );
      expect(usage, isNotNull);
      expect(usage!.promptTokens, 14210);
      expect(usage.cacheHitTokens, 13400);
      expect(usage.cacheMissTokens, 810);
      expect(usage.completionTokens, 1025);
      expect(usage.cacheHitRatio, closeTo(94.3, 0.05));
      final log = usage
          .copyWith(model: 'deepseek-flash', durationMs: 412)
          .formatLog();
      expect(log, contains('Model: deepseek-flash'));
      expect(log, contains('Prompt tokens: 14,210'));
      expect(log, contains('Cache hit tokens: 13,400'));
      expect(log, contains('Cache miss tokens: 810'));
      expect(log, contains('Completion tokens: 1,025'));
      expect(log, contains('Cache hit ratio: 94.3%'));
      expect(log, contains('Request duration: 412ms'));
      expect(log, isNot(contains('sk-')));
    });

    test('handles missing cache fields', () {
      final usage = AiTokenUsage.fromUsageMap({
        'prompt_tokens': 10,
        'completion_tokens': 2,
      });
      expect(usage!.cacheHitTokens, isNull);
      expect(usage.cacheHitRatio, isNull);
      expect(usage.formatLog(), contains('n/a'));
    });
  });

  group('DeepSeek prompt prefix cache layout', () {
    const document =
        'Gradient descent is an iterative optimization algorithm. '
        'It updates parameters in the opposite direction of the gradient of '
        'the cost function. Learning rate controls step size. '
        'This paragraph is repeated so the reusable prefix is large. ';

    AiStudyRequest ask(
      String question, {
      List<AiConversationTurn> conversation = const [],
    }) {
      return AiStudyRequest(
        action: AiStudyAction.askAi,
        sourceText: document * 40,
        selectedText: document * 40,
        language: AiLanguage.english,
        customPrompt: question,
        conversation: conversation,
      );
    }

    test('three follow-up questions share an identical document prefix', () {
      final a = AiPromptBuilder.deepSeekMessages(
        ask('What is this document about?'),
      );
      final b = AiPromptBuilder.deepSeekMessages(
        ask('Give me the three most important points.'),
      );
      final c = AiPromptBuilder.deepSeekMessages(
        ask('Quiz me on this document.'),
      );

      expect(a[0]['role'], 'system');
      expect(a[1]['role'], 'user');
      expect(a[1]['content'], contains('SELECTED TEXT:'));
      expect(a[1]['content'], contains('Gradient descent'));
      expect(a[0]['content'], b[0]['content']);
      expect(a[1]['content'], b[1]['content']);
      expect(a[1]['content'], c[1]['content']);
      expect(a[2]['role'], 'user');
      expect(a[2]['content'], 'What is this document about?');
      expect(b[2]['content'], 'Give me the three most important points.');
    });

    test('follow-ups use real multi-turn roles after the document', () {
      final messages = AiPromptBuilder.deepSeekMessages(
        ask(
          'Question 3',
          conversation: const [
            AiConversationTurn(
              userMessage: 'Question 1',
              assistantMarkdown: 'Answer 1',
            ),
            AiConversationTurn(
              userMessage: 'Question 2',
              assistantMarkdown: 'Answer 2',
            ),
          ],
        ),
      );
      expect(
        messages.map((m) => m['role']).toList(),
        ['system', 'user', 'user', 'assistant', 'user', 'assistant', 'user'],
      );
      expect(messages[1]['content'], contains('SELECTED TEXT:'));
      expect(messages[2]['content'], 'Question 1');
      expect(messages[3]['content'], 'Answer 1');
      expect(messages[4]['content'], 'Question 2');
      expect(messages[5]['content'], 'Answer 2');
      expect(messages[6]['content'], 'Question 3');
      expect(messages[1]['content'], isNot(contains('Question 3')));
    });

    test('HTTP messages use system + document-first multi-turn body', () async {
      final bodies = <Map<String, dynamic>>[];
      var call = 0;
      final client = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        call++;
        final hit = call == 1 ? 0 : 12000;
        final miss = call == 1 ? 12800 : 800;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'Answer $call'},
              },
            ],
            'usage': {
              'prompt_tokens': hit + miss,
              'completion_tokens': 20,
              'total_tokens': hit + miss + 20,
              'prompt_cache_hit_tokens': hit,
              'prompt_cache_miss_tokens': miss,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.deepseek, 'sk-test-key');
      final settings = MemoryAiSettingsStore();
      await settings.setProvider(AiProviderId.deepseek);
      await settings.setPrivacyConsentAccepted(true);
      await settings.setThinkingMode(AiThinkingMode.low);

      final service = DeepSeekAiService(
        credentials: credentials,
        settings: settings,
        httpClient: client,
      );

      final questions = [
        'What is this document about?',
        'Give me the three most important points.',
        'Quiz me on this document.',
      ];
      final results = <AiStudyResult>[];
      for (final q in questions) {
        results.add(await service.run(ask(q)));
      }

      expect(bodies, hasLength(3));
      expect(results[0].usage?.cacheHitTokens, 0);
      expect(results[1].usage?.cacheHitTokens, 12000);
      expect(results[2].usage?.cacheHitTokens, 12000);
      String? document;
      for (final body in bodies) {
        final messages = body['messages'] as List;
        expect(messages[0]['role'], 'system');
        expect(messages[1]['role'], 'user');
        final doc = messages[1]['content'] as String;
        expect(doc, contains('SELECTED TEXT:'));
        document ??= doc;
        expect(doc, document);
        expect(messages.last['role'], 'user');
        expect(messages.last['content'], isNot(contains('SELECTED TEXT:')));
      }
    });
  });

  group('DeepSeek history trim preserves document', () {
    test('drops oldest Q/A before the pinned document turn', () {
      final history = <AiChatTurn>[
        AiChatTurn(
          role: 'user',
          content: 'Attached Study Vault context:\n${'DOC' * 100}',
          pinForCache: true,
        ),
        const AiChatTurn(role: 'assistant', content: 'A1'),
        const AiChatTurn(role: 'user', content: 'Q2'),
        const AiChatTurn(role: 'assistant', content: 'A2'),
        const AiChatTurn(role: 'user', content: 'Q3'),
      ];
      final trimmed = HttpDeepSeekChatService.trimHistoryPreservingDocument(
        history,
        maxMessages: 4,
        maxChars: 80000,
      );
      expect(trimmed.first.content, contains('Attached Study Vault context:'));
      expect(trimmed.last.content, 'Q3');
      expect(trimmed.any((t) => t.content == 'A1'), isFalse);
    });
  });
}
