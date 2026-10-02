import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/deepseek_model_registry.dart';
import 'package:study_vault/features/ai_assistant/domain/gemini_model_registry.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/routing_ai_service.dart';

import 'helpers/ai_selection_helpers.dart';

void main() {
  group('AiExecutionSelection', () {
    test(
      'DeepSeek Auto resolves to concrete model and keeps requested auto',
      () {
        final heavy = testDeepSeekAutoSelection(
          action: AiStudyAction.generateQuestions,
        );
        expect(heavy.requestedModelId, DeepSeekModelIds.auto);
        expect(heavy.resolvedModelId, DeepSeekModelRegistry.v4Pro);
        expect(heavy.resolvedModelId, isNot(DeepSeekModelIds.auto));

        final light = testDeepSeekAutoSelection(action: AiStudyAction.explain);
        expect(light.resolvedModelId, DeepSeekModelRegistry.flash);
      },
    );

    test('fromStored rebuilds selection for regenerate inheritance', () {
      final selection = AiExecutionSelection.fromStored(
        provider: AiProviderId.deepseek,
        modelId: DeepSeekModelRegistry.flash,
        action: AiStudyAction.summarize,
      );
      expect(selection.provider, AiProviderId.deepseek);
      expect(selection.resolvedModelId, DeepSeekModelRegistry.flash);
    });

    test('vision constraints disable DeepSeek', () {
      expect(AiExecutionConstraints.vision.deepSeekEnabled, isFalse);
      expect(
        AiExecutionConstraints.vision.reasonDeepSeekDisabled,
        contains('DeepSeek'),
      );
    });
  });

  group('RoutingAiService selection', () {
    late MemoryAiSettingsStore settings;
    late FakeAiService gemini;
    late FakeAiService deepseek;
    late RoutingAiService router;
    final calls = <({String backend, String model})>[];

    setUp(() {
      settings = MemoryAiSettingsStore();
      calls.clear();
      gemini = FakeAiService(
        handler: (request) async {
          calls.add((
            backend: 'gemini',
            model: request.selection.resolvedModelId,
          ));
          return AiTextResult(
            markdown: 'gemini:${request.selection.resolvedModelId}',
          );
        },
      );
      deepseek = FakeAiService(
        handler: (request) async {
          calls.add((
            backend: 'deepseek',
            model: request.selection.resolvedModelId,
          ));
          return AiTextResult(
            markdown: 'deepseek:${request.selection.resolvedModelId}',
          );
        },
      );
      router = RoutingAiService(
        settings: settings,
        gemini: gemini,
        deepseek: deepseek,
      );
    });

    test('Gemini selection reaches Gemini with selected model', () async {
      await settings.setProvider(AiProviderId.deepseek);
      final selection = testGeminiSelection(
        action: AiStudyAction.explain,
        modelId: GeminiModelRegistry.defaultModelId,
      );
      final result = await router.run(
        AiStudyRequest(
          action: AiStudyAction.explain,
          sourceText: 'hello',
          selection: selection,
        ),
      );
      expect(result, isA<AiTextResult>());
      expect(calls.single.backend, 'gemini');
      expect(calls.single.model, selection.resolvedModelId);
      // Global settings unchanged.
      expect(await settings.getProvider(), AiProviderId.deepseek);
    });

    test('DeepSeek selection reaches DeepSeek', () async {
      await settings.setProvider(AiProviderId.gemini);
      final selection = testDeepSeekSelection(action: AiStudyAction.explain);
      await router.run(
        AiStudyRequest(
          action: AiStudyAction.explain,
          sourceText: 'hello',
          selection: selection,
        ),
      );
      expect(calls.single.backend, 'deepseek');
      expect(await settings.getProvider(), AiProviderId.gemini);
    });

    test('vision requests force Gemini even if DeepSeek selected', () async {
      final selection = testDeepSeekSelection(action: AiStudyAction.explain);
      await router.run(
        AiStudyRequest(
          action: AiStudyAction.explain,
          sourceText: 'page',
          selection: selection,
          image: AiStudyImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/jpeg',
            pageNumber: 1,
          ),
        ),
      );
      expect(calls.single.backend, 'gemini');
    });

    test('DeepSeek Auto persists resolved model on the request path', () async {
      final selection = testDeepSeekAutoSelection(
        action: AiStudyAction.generateFlashcards,
      );
      expect(selection.resolvedModelId, DeepSeekModelRegistry.v4Pro);
      await router.run(
        AiStudyRequest(
          action: AiStudyAction.generateFlashcards,
          sourceText: 'cards',
          selection: selection,
        ),
      );
      expect(calls.single.model, DeepSeekModelRegistry.v4Pro);
    });
  });
}
