import 'package:flutter/foundation.dart';

import '../data/ai_settings_store.dart';
import 'ai_actions.dart';
import 'ai_provider.dart';
import 'deepseek_model_registry.dart';
import 'gemini_model_registry.dart';

/// Constraints that filter which models a picker may offer for one request.
@immutable
class AiExecutionConstraints {
  const AiExecutionConstraints({
    this.visionOnly = false,
    this.allowDeepSeek = true,
    this.allowAuto = true,
    this.reasonDeepSeekDisabled,
  });

  /// Page / question image requests must use Gemini vision models.
  final bool visionOnly;

  final bool allowDeepSeek;

  /// Whether DeepSeek "Auto" appears in the catalog.
  final bool allowAuto;

  /// Shown when DeepSeek rows are disabled (e.g. vision).
  final String? reasonDeepSeekDisabled;

  static const none = AiExecutionConstraints();

  static const vision = AiExecutionConstraints(
    visionOnly: true,
    allowDeepSeek: false,
    allowAuto: false,
    reasonDeepSeekDisabled: 'DeepSeek cannot receive page images. Use Gemini.',
  );

  bool get deepSeekEnabled => allowDeepSeek && !visionOnly;
}

/// Explicit provider/model choice for one LLM execution.
///
/// Services must use this instead of re-reading global settings after the user
/// has picked a model.
@immutable
class AiExecutionSelection {
  const AiExecutionSelection({
    required this.provider,
    required this.requestedModelId,
    required this.resolvedModelId,
    this.thinkingMode,
  });

  final AiProviderId provider;

  /// May be DeepSeek `auto`.
  final String requestedModelId;

  /// Concrete model id after Auto expansion / normalization.
  final String resolvedModelId;

  /// DeepSeek thinking override; null means resolve from prefs / action Auto.
  final AiThinkingMode? thinkingMode;

  String get providerStorage => provider.storageValue;

  AiGenerationMeta get asMeta =>
      AiGenerationMeta(provider: provider, modelId: resolvedModelId);

  AiExecutionSelection copyWith({
    AiProviderId? provider,
    String? requestedModelId,
    String? resolvedModelId,
    AiThinkingMode? thinkingMode,
  }) {
    return AiExecutionSelection(
      provider: provider ?? this.provider,
      requestedModelId: requestedModelId ?? this.requestedModelId,
      resolvedModelId: resolvedModelId ?? this.resolvedModelId,
      thinkingMode: thinkingMode ?? this.thinkingMode,
    );
  }

  /// Builds a selection from the user's global Settings defaults.
  static Future<AiExecutionSelection> fromGlobal(
    AiSettingsStore settings, {
    required AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) async {
    final provider = await settings.getProvider();
    final requested = await settings.getModelIdFor(provider);
    final thinking =
        thinkingMode ??
        (provider == AiProviderId.deepseek
            ? await settings.getThinkingMode()
            : null);
    return resolve(
      provider: provider,
      requestedModelId: requested,
      action: action,
      thinkingMode: thinking,
    );
  }

  /// Rebuilds a selection from a previously persisted generation.
  static AiExecutionSelection fromStored({
    required AiProviderId provider,
    required String modelId,
    AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) {
    return resolve(
      provider: provider,
      requestedModelId: modelId,
      action: action,
      thinkingMode: thinkingMode,
    );
  }

  /// Infers provider from [modelId] and resolves Auto.
  static AiExecutionSelection fromModelId(
    String modelId, {
    AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) {
    final provider = AiProviderIdX.fromModelId(modelId);
    return resolve(
      provider: provider,
      requestedModelId: modelId,
      action: action,
      thinkingMode: thinkingMode,
    );
  }

  static AiExecutionSelection resolve({
    required AiProviderId provider,
    required String requestedModelId,
    required AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) {
    final requested = requestedModelId.trim();
    final resolved = resolveActiveModelId(
      provider: provider,
      storedModelId: requested,
      action: action,
    );
    return AiExecutionSelection(
      provider: provider,
      requestedModelId: switch (provider) {
        AiProviderId.gemini => GeminiModelRegistry.normalize(requested),
        AiProviderId.deepseek =>
          DeepSeekModelIds.isAuto(requested)
              ? DeepSeekModelIds.auto
              : DeepSeekModelRegistry.normalize(requested),
      },
      resolvedModelId: resolved,
      thinkingMode: thinkingMode,
    );
  }

  /// Forces Gemini when the request carries a page image.
  AiExecutionSelection ensureVisionCompatible({
    required String geminiModelId,
    AiStudyAction? action,
  }) {
    if (provider == AiProviderId.gemini) return this;
    return resolve(
      provider: AiProviderId.gemini,
      requestedModelId: geminiModelId,
      action: action,
      thinkingMode: null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AiExecutionSelection &&
        other.provider == provider &&
        other.requestedModelId == requestedModelId &&
        other.resolvedModelId == resolvedModelId &&
        other.thinkingMode == thinkingMode;
  }

  @override
  int get hashCode =>
      Object.hash(provider, requestedModelId, resolvedModelId, thinkingMode);
}
