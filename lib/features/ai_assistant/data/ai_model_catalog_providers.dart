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

      final newApiId = await ref
          .watch(aiSettingsStoreProvider)
          .getModelIdFor(AiProviderId.newApi);
      if (newApiId.length > 7 &&
          !models.any((m) => m.provider == AiProviderId.newApi)) {
        models = [
          ...models,
          AiSelectableModel(
            id: newApiId,
            displayName: newApiId.substring(7),
            description: 'Claude Messages via your New API server',
            recommended: false,
            group: 'Other',
            provider: AiProviderId.newApi,
          ),
        ];
      }
      final creds = ref.watch(aiCredentialStoreProvider);
      final geminiReady = await creds.hasApiKeyFor(AiProviderId.gemini);
      final deepSeekReady = await creds.hasApiKeyFor(AiProviderId.deepseek);
      final newApiReady =
          await creds.hasApiKeyFor(AiProviderId.newApi) &&
          (await ref.watch(aiSettingsStoreProvider).getNewApiBaseUrl())
              .isNotEmpty;

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
              newApiReady: newApiReady,
            ),
      ];
    });

AiSelectableModel _applyConstraints(
  AiSelectableModel model, {
  required AiExecutionConstraints constraints,
  required bool geminiReady,
  required bool deepSeekReady,
  required bool newApiReady,
}) {
  if (model.provider == AiProviderId.newApi) {
    if (constraints.visionOnly) {
      return model.copyWith(
        enabled: false,
        disabledReason: 'Use Gemini for page images.',
      );
    }
    return newApiReady
        ? model
        : model.copyWith(
            enabled: false,
            disabledReason: 'Add a New API key and server URL in Settings.',
          );
  }
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
