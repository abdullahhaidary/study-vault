import 'ai_endpoint_profile.dart';
import 'ai_model_ref.dart';
import 'ai_provider.dart';
import 'ai_selectable_model.dart';

const customProfileVisionReason =
    'Custom API profiles are text-only. Use a Gemini vision model.';

/// Picker rows for custom profiles. Identical model ids on different profiles
/// stay distinct because each row carries that profile's id.
List<AiSelectableModel> selectableModelsForEndpointProfiles(
  List<AiEndpointProfile> profiles, {
  bool visionOnly = false,
}) {
  final rows = <AiSelectableModel>[];
  for (final profile in profiles) {
    final seen = <String>{};
    final ids = <String>[
      ...profile.cachedModelIds,
      if (profile.defaultModelId.trim().isNotEmpty)
        profile.defaultModelId.trim(),
    ];
    for (final modelId in ids) {
      final bare = modelId.trim();
      if (bare.isEmpty || !seen.add(bare)) continue;
      final missingFromCache = !profile.cachedModelIds.contains(bare);
      final ref = EndpointAiModelRef(profileId: profile.id, modelId: bare);
      final blocked = _blockReason(profile, visionOnly: visionOnly);
      rows.add(
        AiSelectableModel(
          id: ref.storageValue,
          displayName: bare,
          description: missingFromCache
              ? 'Previously selected — unavailable'
              : '${profile.host} · ${profile.modelListLabel}',
          recommended: bare == profile.defaultModelId,
          group: profile.name,
          section: profile.name,
          provider: AiProviderId.newApi,
          supportsVision: false,
          enabled: blocked == null,
          disabledReason: blocked,
          endpointProfileId: profile.id,
          endpointHost: profile.host,
          modelListStale:
              profile.modelsStale || profile.modelsRefreshedAt == null,
          modelRef: ref,
        ),
      );
    }
  }
  return rows;
}

String? _blockReason(AiEndpointProfile profile, {required bool visionOnly}) {
  if (visionOnly) return customProfileVisionReason;
  if (!profile.enabled) return 'This profile is turned off.';
  if (profile.baseUrl.isEmpty || profile.keySuffix.isEmpty) {
    return 'Add an API key for this profile in Settings.';
  }
  return null;
}
