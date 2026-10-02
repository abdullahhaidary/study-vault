import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_chat/data/ai_chat_providers.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_selectable_model.dart';
import '../domain/deepseek_model_registry.dart';
import '../domain/gemini_model_registry.dart';
import 'ai_providers.dart';

/// Shared catalog of Gemini + DeepSeek models for study and chat pickers.
final availableAiModelsProvider =
    FutureProvider.family<List<AiSelectableModel>, AiExecutionConstraints>((
      ref,
      constraints,
    ) async {
      List<AiSelectableModel> models;
      try {
        models = await ref
            .watch(aiChatTransportProvider)
            .listAvailableChatModels();
      } catch (_) {
        models = [
          ...GeminiModelRegistry.fallbackChatModels().map(
            AiSelectableModel.fromGemini,
          ),
          ...DeepSeekModelRegistry.selectableModels().map(
            AiSelectableModel.fromDeepSeek,
          ),
        ];
      }

      if (models.isEmpty) {
        models = [
          ...GeminiModelRegistry.fallbackChatModels().map(
            AiSelectableModel.fromGemini,
          ),
          ...DeepSeekModelRegistry.selectableModels().map(
            AiSelectableModel.fromDeepSeek,
          ),
        ];
      }

      final creds = ref.watch(aiCredentialStoreProvider);
      final geminiReady = await creds.hasApiKeyFor(AiProviderId.gemini);
      final deepSeekReady = await creds.hasApiKeyFor(AiProviderId.deepseek);

      return [
        for (final model in models)
          if (!(model.provider == AiProviderId.deepseek &&
              !constraints.allowAuto &&
              DeepSeekModelIds.isAuto(model.id)))
            _applyConstraints(
              model,
              constraints: constraints,
              geminiReady: geminiReady,
              deepSeekReady: deepSeekReady,
            ),
      ];
    });

AiSelectableModel _applyConstraints(
  AiSelectableModel model, {
  required AiExecutionConstraints constraints,
  required bool geminiReady,
  required bool deepSeekReady,
}) {
  if (model.provider == AiProviderId.gemini) {
    if (!geminiReady) {
      return model.copyWith(
        enabled: false,
        disabledReason: 'Add a Gemini API key in Settings.',
      );
    }
    if (constraints.visionOnly && !model.supportsVision) {
      return model.copyWith(
        enabled: false,
        disabledReason: 'This model cannot receive page images.',
      );
    }
    return model;
  }

  if (!constraints.deepSeekEnabled) {
    return model.copyWith(
      enabled: false,
      disabledReason:
          constraints.reasonDeepSeekDisabled ??
          'DeepSeek is unavailable for this request.',
    );
  }
  if (!deepSeekReady) {
    return model.copyWith(
      enabled: false,
      disabledReason: 'Add a DeepSeek API key in Settings.',
    );
  }
  return model;
}
