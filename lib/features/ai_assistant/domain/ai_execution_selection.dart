import 'package:flutter/foundation.dart';

import '../data/ai_settings_store.dart';
import 'ai_actions.dart';
import 'ai_model_ref.dart';
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
    this.endpointProfileId,
    this.thinkingMode,
  });

  final AiProviderId provider;

  /// May be DeepSeek `auto`. Custom models keep the `newapi:` prefix here.
  final String requestedModelId;

  /// Concrete model id after Auto expansion / normalization.
  final String resolvedModelId;

  /// Custom endpoint that must serve this request. Null for built-in providers
  /// and for legacy `newapi:` rows that still bind to the migrated profile.
  final String? endpointProfileId;

  /// DeepSeek thinking override; null means resolve from prefs / action Auto.
  final AiThinkingMode? thinkingMode;

  String get providerStorage => provider.storageValue;

  AiModelRef get modelRef {
    if (provider == AiProviderId.newApi) {
      final bare = newApiBareModelId(resolvedModelId);
      final profileId = endpointProfileId;
      if (profileId != null && profileId.isNotEmpty) {
        return EndpointAiModelRef(profileId: profileId, modelId: bare);
      }
      return LegacyNewApiModelRef(bare);
    }
    if (provider == AiProviderId.deepseek) {
      return BuiltinDeepSeekModelRef(requestedModelId);
    }
    return BuiltinGeminiModelRef(resolvedModelId);
  }

  String get persistedModelId => modelRef.storageValue;

  AiGenerationMeta get asMeta =>
      AiGenerationMeta(provider: provider, modelId: resolvedModelId);

  AiExecutionSelection copyWith({
    AiProviderId? provider,
    String? requestedModelId,
    String? resolvedModelId,
    String? endpointProfileId,
    AiThinkingMode? thinkingMode,
  }) {
    return AiExecutionSelection(
      provider: provider ?? this.provider,
      requestedModelId: requestedModelId ?? this.requestedModelId,
      resolvedModelId: resolvedModelId ?? this.resolvedModelId,
      endpointProfileId: endpointProfileId ?? this.endpointProfileId,
      thinkingMode: thinkingMode ?? this.thinkingMode,
    );
  }

  /// Builds a selection from the user's global Settings defaults.
  static Future<AiExecutionSelection> fromGlobal(
    AiSettingsStore settings, {
    required AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) async {
    final model = await settings.getGlobalModelRef();
    final thinking =
        thinkingMode ??
        (model.provider == AiProviderId.deepseek
            ? await settings.getThinkingMode()
            : null);
    return fromModelRef(model, action: action, thinkingMode: thinking);
  }

  /// Rebuilds a selection from a previously persisted generation.
  static AiExecutionSelection fromStored({
    required AiProviderId provider,
    required String modelId,
    String? endpointProfileId,
    AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) {
    return resolve(
      provider: provider,
      requestedModelId: modelId,
      endpointProfileId: endpointProfileId,
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
    return fromModelRef(
      AiModelRef.parse(modelId),
      action: action,
      thinkingMode: thinkingMode,
    );
  }

  static AiExecutionSelection fromModelRef(
    AiModelRef ref, {
    AiStudyAction? action,
    AiThinkingMode? thinkingMode,
  }) {
    return resolve(
      provider: ref.provider,
      requestedModelId: ref.providerModelId,
      endpointProfileId: ref.endpointProfileId,
      action: action,
      thinkingMode: thinkingMode,
    );
  }

  static AiExecutionSelection resolve({
    required AiProviderId provider,
    required String requestedModelId,
    required AiStudyAction? action,
    String? endpointProfileId,
    AiThinkingMode? thinkingMode,
  }) {
    final parsed = AiModelRef.parse(requestedModelId);
    final profileId = provider == AiProviderId.newApi
        ? endpointProfileId ?? parsed.endpointProfileId
        : null;
    final requested = switch (provider) {
      AiProviderId.gemini => GeminiModelRegistry.normalize(
        parsed is BuiltinGeminiModelRef ? parsed.bareModelId : requestedModelId,
      ),
      AiProviderId.newApi => normalizeNewApiModelId(
        parsed is EndpointAiModelRef || parsed is LegacyNewApiModelRef
            ? parsed.bareModelId
            : newApiBareModelId(requestedModelId),
      ),
      AiProviderId.deepseek =>
        DeepSeekModelIds.isAuto(requestedModelId)
            ? DeepSeekModelIds.auto
            : DeepSeekModelRegistry.normalize(requestedModelId),
    };
    final resolved = resolveActiveModelId(
      provider: provider,
      storedModelId: requested,
      action: action,
    );
    return AiExecutionSelection(
      provider: provider,
      requestedModelId: requested,
      resolvedModelId: resolved,
      endpointProfileId: profileId,
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
        other.endpointProfileId == endpointProfileId &&
        other.thinkingMode == thinkingMode;
  }

  @override
  int get hashCode => Object.hash(
    provider,
    requestedModelId,
    resolvedModelId,
    endpointProfileId,
    thinkingMode,
  );
}
