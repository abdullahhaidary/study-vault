import 'ai_model_ref.dart';
import 'ai_provider.dart';
import 'deepseek_model_registry.dart';
import 'gemini_model_registry.dart';

/// Provider-agnostic model row for shared AI model pickers.
class AiSelectableModel {
  const AiSelectableModel({
    required this.id,
    required this.displayName,
    required this.description,
    required this.recommended,
    required this.group,
    required this.provider,
    this.section = '',
    this.supportsVision = false,
    this.enabled = true,
    this.disabledReason,
    this.endpointProfileId,
    this.endpointHost,
    this.modelListStale = false,
    this.modelRef,
  });

  final String id;
  final String displayName;
  final String description;
  final bool recommended;

  /// Legacy intra-provider group (Recommended / Fast / Other).
  final String group;

  /// Picker heading. Custom profiles use their display name.
  final String section;

  final AiProviderId provider;
  final bool supportsVision;
  final bool enabled;
  final String? disabledReason;
  final String? endpointProfileId;
  final String? endpointHost;
  final bool modelListStale;
  final AiModelRef? modelRef;

  String get sectionLabel => section.isEmpty ? provider.displayName : section;

  AiSelectableModel copyWith({bool? enabled, String? disabledReason}) {
    return AiSelectableModel(
      id: id,
      displayName: displayName,
      description: description,
      recommended: recommended,
      group: group,
      section: section,
      provider: provider,
      supportsVision: supportsVision,
      enabled: enabled ?? this.enabled,
      disabledReason: disabledReason ?? this.disabledReason,
      endpointProfileId: endpointProfileId,
      endpointHost: endpointHost,
      modelListStale: modelListStale,
      modelRef: modelRef,
    );
  }

  factory AiSelectableModel.fromGemini(GeminiModelDefinition m) {
    final group = switch (m.tier) {
      GeminiModelTier.recommended => 'Recommended',
      GeminiModelTier.fast => 'Fast',
      _ => m.recommended ? 'Recommended' : 'Other',
    };
    return AiSelectableModel(
      id: m.id,
      displayName: m.displayName,
      description: m.description,
      recommended: m.recommended,
      group: group,
      provider: AiProviderId.gemini,
      supportsVision: true,
    );
  }

  factory AiSelectableModel.fromDeepSeek(DeepSeekModelDefinition m) {
    return AiSelectableModel(
      id: m.id,
      displayName: m.displayName,
      description: m.description,
      recommended: m.recommended,
      group: m.recommended ? 'Recommended' : 'Other',
      provider: AiProviderId.deepseek,
      supportsVision: m.supportsVision,
    );
  }
}
