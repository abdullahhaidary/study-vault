import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_chat/data/ai_chat_providers.dart';
import '../domain/ai_endpoint_catalog.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_selectable_model.dart';
import '../domain/deepseek_model_registry.dart';
import '../domain/gemini_model_registry.dart';
import 'ai_providers.dart';

final _discoveredModelCacheProvider =
    Provider<Map<int, List<AiSelectableModel>>>((ref) => {});

/// Providers publish independently: slow discovery never hides cached rows.
final discoveredAiModelsProvider = StreamProvider<List<AiSelectableModel>>((
  ref,
) {
  final transports = [
    ref.watch(geminiChatServiceProvider),
    ref.watch(deepseekChatServiceProvider),
    ref.watch(pocketChatServiceProvider),
  ];
  final saved = ref.watch(_discoveredModelCacheProvider);
  final groups = <List<AiSelectableModel>>[
    GeminiModelRegistry.fallbackChatModels()
        .map(AiSelectableModel.fromGemini)
        .toList(),
    DeepSeekModelRegistry.selectableModels()
        .map(AiSelectableModel.fromDeepSeek)
        .toList(),
    pocketSelectableModels(),
  ];
  for (var i = 0; i < groups.length; i++) {
    groups[i] = saved[i] ?? groups[i];
  }
  final running = <int>{};
  final controller = StreamController<List<AiSelectableModel>>();
  void publish() {
    if (!controller.isClosed) controller.add(groups.expand((g) => g).toList());
  }

  publish();
  Future<void> discover(int i) async {
    if (!running.add(i)) return;
    try {
      final models = await transports[i].listAvailableChatModels();
      if (controller.isClosed) return;
      if (models.isNotEmpty) {
        groups[i] = models;
        saved[i] = models;
      }
      publish();
    } on Object {
      // Keep the last successful catalog when a provider is unavailable.
    } finally {
      running.remove(i);
    }
  }

  for (var i = 0; i < transports.length; i++) {
    unawaited(discover(i));
  }
  final timer = Timer.periodic(const Duration(hours: 24), (_) {
    for (var i = 0; i < transports.length; i++) {
      unawaited(discover(i));
    }
  });
  ref.onDispose(timer.cancel);
  ref.onDispose(controller.close);
  return controller.stream;
});

/// Refresh statuses are shared between Settings and every model picker.
final refreshingModelProfilesProvider = StreamProvider<Set<String>>((
  ref,
) async* {
  final service = ref.watch(newApiClaudeServiceProvider);
  yield Set.of(service.refreshingProfileIds);
  await for (final _ in service.refreshChanges) {
    yield Set.of(service.refreshingProfileIds);
  }
});

final _modelCatalogClockProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (tick) => tick);
});

/// Cached custom models appear immediately; expiry initiates a background GET.
final availableAiModelsProvider =
    FutureProvider.family<List<AiSelectableModel>, AiExecutionConstraints>((
      ref,
      constraints,
    ) async {
      ref.watch(_modelCatalogClockProvider);
      final discovered = ref.watch(discoveredAiModelsProvider).valueOrNull;
      final profileFuture = ref.watch(aiEndpointProfilesProvider.future);
      final service = ref.watch(newApiClaudeServiceProvider);
      final creds = ref.watch(aiCredentialStoreProvider);
      final profiles = await profileFuture;
      for (final profile in profiles) {
        unawaited(service.refreshModelsIfStale(profile));
      }
      final models = [
        ...?discovered,
        if (discovered == null) ...[
          ...GeminiModelRegistry.fallbackChatModels().map(
            AiSelectableModel.fromGemini,
          ),
          ...DeepSeekModelRegistry.selectableModels().map(
            AiSelectableModel.fromDeepSeek,
          ),
          ...pocketSelectableModels(),
        ],
        ...selectableModelsForEndpointProfiles(
          profiles,
          visionOnly: constraints.visionOnly,
        ),
      ];
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
  if (model.provider == AiProviderId.pocket) return model;
  if (model.endpointProfileId != null ||
      model.provider == AiProviderId.newApi) {
    if (constraints.visionOnly) {
      return model.copyWith(
        enabled: false,
        disabledReason: customProfileVisionReason,
      );
    }
    return model;
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
