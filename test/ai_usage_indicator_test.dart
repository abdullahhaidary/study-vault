import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_token_usage.dart';
import 'package:study_vault/features/ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import 'package:study_vault/features/ai_chat/presentation/widgets/message_bubble.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiTokenUsage.compactLabel', () {
    test('tokens + cached', () {
      const usage = AiTokenUsage(
        totalTokens: 15900,
        cacheHitTokens: 14000,
      );
      expect(usage.compactLabel, '15.9K tokens · 14K cached');
    });

    test('tokens only when cache is null', () {
      const usage = AiTokenUsage(totalTokens: 2800);
      expect(usage.compactLabel, '2.8K tokens');
    });

    test('formatCompactTokens examples', () {
      expect(AiTokenUsage.formatCompactTokens(950), '950');
      expect(AiTokenUsage.formatCompactTokens(1200), '1.2K');
      expect(AiTokenUsage.formatCompactTokens(15900), '15.9K');
      expect(AiTokenUsage.formatCompactTokens(1100000), '1.1M');
    });
  });

  group('AiUsageIndicator', () {
    testWidgets('compact text and details dialog', (tester) async {
      const usage = AiTokenUsage(
        promptTokens: 15000,
        completionTokens: 900,
        totalTokens: 15900,
        cacheHitTokens: 14000,
        cacheMissTokens: 1000,
        model: 'deepseek-flash',
        provider: 'deepseek',
        durationMs: 2400,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiUsageIndicator(usage: usage)),
        ),
      );

      expect(find.text('15.9K tokens · 14K cached'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('AI Usage'), findsOneWidget);
      expect(find.text('DeepSeek'), findsOneWidget);
      expect(find.text('deepseek-flash'), findsOneWidget);
      expect(find.text('15,000'), findsOneWidget);
      expect(find.text('14,000'), findsOneWidget);
      expect(find.text('1,000'), findsOneWidget);
      expect(find.text('93.3%'), findsOneWidget);
      expect(find.text('900'), findsOneWidget);
      expect(find.text('15,900'), findsOneWidget);
      expect(find.text('2.4 s'), findsOneWidget);
    });

    testWidgets('no cache metrics shows tokens only', (tester) async {
      const usage = AiTokenUsage(totalTokens: 2800, provider: 'gemini');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiUsageIndicator(usage: usage)),
        ),
      );

      expect(find.text('2.8K tokens'), findsOneWidget);
      expect(find.textContaining('cached'), findsNothing);
    });

    testWidgets('blank usage renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiUsageIndicator(usage: AiTokenUsage())),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('tokens'), findsNothing);
    });
  });

  group('feature surfaces', () {
    testWidgets('AI Chat assistant bubble shows usage', (tester) async {
      const usage = AiTokenUsage(
        totalTokens: 15900,
        cacheHitTokens: 14000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              role: AiChatRole.assistant,
              content: 'Gradient descent works by…',
              usage: usage,
            ),
          ),
        ),
      );

      expect(find.text('15.9K tokens · 14K cached'), findsOneWidget);
    });

    testWidgets('user messages never show usage', (tester) async {
      const usage = AiTokenUsage(totalTokens: 100);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              role: AiChatRole.user,
              content: 'What is gradient descent?',
              usage: usage,
            ),
          ),
        ),
      );

      expect(find.textContaining('tokens'), findsNothing);
    });

    testWidgets('streaming assistant hides usage until complete', (
      tester,
    ) async {
      const usage = AiTokenUsage(totalTokens: 500);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              role: AiChatRole.assistant,
              content: 'Partial…',
              isStreaming: true,
              usage: usage,
            ),
          ),
        ),
      );

      expect(find.textContaining('tokens'), findsNothing);
    });

    test('aiTokenUsageFromColumns returns null when empty', () {
      expect(aiTokenUsageFromColumns(), isNull);
    });

    test('aiTokenUsageFromColumns rebuilds usage', () {
      final usage = aiTokenUsageFromColumns(
        promptTokens: 10,
        completionTokens: 2,
        totalTokens: 12,
        provider: 'deepseek',
      );
      expect(usage, isNotNull);
      expect(usage!.totalTokens, 12);
      expect(usage.compactLabel, '12 tokens');
    });
  });
}
