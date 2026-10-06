import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/services/gemini_retry_policy.dart';

void main() {
  group('GeminiRetryPolicy', () {
    test('retries rate limits using increasing delays', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setGeminiRetryCount(3);
      final delays = <Duration>[];
      var attempts = 0;

      final result = await GeminiRetryPolicy.run(
        settings: settings,
        delay: (duration) async => delays.add(duration),
        operation: () async {
          attempts++;
          if (attempts < 3) throw const AiRateLimitException();
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 3);
      expect(delays, const [Duration(seconds: 2), Duration(seconds: 4)]);
    });

    test('stops after the configured number of retries', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setGeminiRetryCount(2);
      var attempts = 0;

      await expectLater(
        GeminiRetryPolicy.run<void>(
          settings: settings,
          delay: (_) async {},
          operation: () async {
            attempts++;
            throw const AiQuotaException();
          },
        ),
        throwsA(isA<AiQuotaException>()),
      );

      expect(attempts, 3);
    });

    test('does not retry non-rate-limit errors', () async {
      final settings = MemoryAiSettingsStore();
      var attempts = 0;

      await expectLater(
        GeminiRetryPolicy.run<void>(
          settings: settings,
          delay: (_) async {},
          operation: () async {
            attempts++;
            throw const AiInvalidKeyException();
          },
        ),
        throwsA(isA<AiInvalidKeyException>()),
      );

      expect(attempts, 1);
    });

    test('fails over to the next Gemini key without waiting', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setGeminiRetryCount(0);
      final delays = <Duration>[];
      final used = <String>[];

      final result = await GeminiRetryPolicy.runWithKeys(
        settings: settings,
        keys: const ['dead-key', 'live-key'],
        delay: (duration) async => delays.add(duration),
        operation: (apiKey) async {
          used.add(apiKey);
          if (apiKey == 'dead-key') throw const AiQuotaException();
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(used, ['dead-key', 'live-key']);
      expect(delays, isEmpty);
    });

    test('tries every key before giving up', () async {
      final settings = MemoryAiSettingsStore();
      await settings.setGeminiRetryCount(0);
      final used = <String>[];

      await expectLater(
        GeminiRetryPolicy.runWithKeys<void>(
          settings: settings,
          keys: const ['a', 'b', 'c'],
          delay: (_) async {},
          operation: (apiKey) async {
            used.add(apiKey);
            throw const AiRateLimitException();
          },
        ),
        throwsA(isA<AiRateLimitException>()),
      );

      expect(used, ['a', 'b', 'c']);
    });
  });
}
