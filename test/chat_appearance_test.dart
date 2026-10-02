import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/features/ai_chat/data/chat_appearance_providers.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/domain/chat_appearance.dart';
import 'package:study_vault/features/ai_chat/presentation/widgets/message_bubble.dart';

void main() {
  test('chat appearance round-trips through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesChatAppearanceStore(preferences);
    const expected = ChatAppearance(
      layout: ChatMessageLayout.fullWidth,
      backgroundKind: ChatBackgroundKind.gradient,
      textScale: 1.3,
      userColorValue: 0xff123456,
      assistantColorValue: 0xff654321,
      gradientStartValue: 0xff000000,
      gradientEndValue: 0xffffffff,
    );

    await store.save(expected);
    final actual = await store.load();

    expect(actual.layout, expected.layout);
    expect(actual.backgroundKind, expected.backgroundKind);
    expect(actual.textScale, expected.textScale);
    expect(actual.userColorValue, expected.userColorValue);
    expect(actual.assistantColorValue, expected.assistantColorValue);
    expect(actual.gradientStartValue, expected.gradientStartValue);
    expect(actual.gradientEndValue, expected.gradientEndValue);
  });

  test('invalid stored appearance safely returns defaults', () async {
    SharedPreferences.setMockInitialValues({
      'ai_chat_appearance_v1': 'not-json',
    });
    final preferences = await SharedPreferences.getInstance();
    final actual = await SharedPreferencesChatAppearanceStore(
      preferences,
    ).load();

    expect(actual.layout, ChatAppearance.defaults.layout);
    expect(actual.textScale, ChatAppearance.defaults.textScale);
  });

  testWidgets('message actions expose copy, edit, and regenerate controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MessageBubble(
                role: AiChatRole.user,
                content: 'My prompt',
                onEditAndResend: () {},
              ),
              MessageBubble(
                role: AiChatRole.assistant,
                content: 'AI response',
                onRegenerate: () {},
                onToggleReadAloud: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Copy message'), findsNWidgets(2));
    expect(find.byTooltip('Edit and resend'), findsOneWidget);
    expect(find.byTooltip('Regenerate response'), findsOneWidget);
    expect(find.byTooltip('Read aloud'), findsOneWidget);
  });
}
