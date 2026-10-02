import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/data/voice_input_providers.dart';
import 'package:study_vault/features/ai_assistant/presentation/widgets/voice_input_button.dart';
import 'package:study_vault/features/ai_assistant/services/voice_input_service.dart';

void main() {
  testWidgets('VoiceInputButton renders mic tooltip without auto-send', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Explain');
    var sends = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceInputServiceProvider.overrideWith((ref) => VoiceInputService()),
          voiceAiSettingsStoreProvider.overrideWithValue(
            MemoryAiSettingsStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(child: TextField(controller: controller)),
                VoiceInputButton(controller: controller),
                IconButton(
                  tooltip: 'Send',
                  onPressed: () => sends++,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Tap to speak'), findsOneWidget);
    expect(controller.text, 'Explain');
    expect(sends, 0);

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sends, 1);
  });
}
