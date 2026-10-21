import 'ai_provider.dart';
import 'deepseek_model_registry.dart';

/// Structured identity for one selectable model.
///
/// Built-in Gemini and DeepSeek models stay distinct from custom endpoint
/// models. Two endpoint profiles that expose the same model id are different
/// refs because each carries its own profile id.
sealed class AiModelRef {
  const AiModelRef();

  AiProviderId get provider;

  /// Model id without provider or profile prefixes.
  String get bareModelId;

  /// Value passed to the existing provider model fields (`newapi:<id>`).
  String get providerModelId;

  /// Profile that owns a custom model. Null for built-in providers.
  String? get endpointProfileId;

  /// Stable persistence form. Gemini and DeepSeek keep their historical ids.
  String get storageValue;

  static final _endpoint = RegExp(
    r'^sv1:endpoint:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}):(.+)$',
  );

  static AiModelRef parse(String raw) {
    final value = raw.trim();
    final endpoint = _endpoint.firstMatch(value);
    if (endpoint != null) {
      return EndpointAiModelRef(
        profileId: endpoint.group(1)!,
        modelId: endpoint.group(2)!.trim(),
      );
    }
    if (value.startsWith('sv1:deepseek:')) {
      return BuiltinDeepSeekModelRef(value.substring('sv1:deepseek:'.length));
    }
    if (value.startsWith('sv1:gemini:')) {
      return BuiltinGeminiModelRef(value.substring('sv1:gemini:'.length));
    }
    if (value.startsWith('newapi:')) {
      return LegacyNewApiModelRef(value.substring(7).trim());
    }
    if (DeepSeekModelIds.isAuto(value) ||
        value.toLowerCase().startsWith('deepseek')) {
      return BuiltinDeepSeekModelRef(value);
    }
    return BuiltinGeminiModelRef(value);
  }

  @override
  bool operator ==(Object other) {
    return other is AiModelRef && other.storageValue == storageValue;
  }

  @override
  int get hashCode => storageValue.hashCode;
}

final class BuiltinGeminiModelRef extends AiModelRef {
  const BuiltinGeminiModelRef(this.modelId);

  final String modelId;

  @override
  AiProviderId get provider => AiProviderId.gemini;

  @override
  String get bareModelId => modelId.trim();

  @override
  String get providerModelId => bareModelId;

  @override
  String? get endpointProfileId => null;

  @override
  String get storageValue => bareModelId;
}

final class BuiltinDeepSeekModelRef extends AiModelRef {
  const BuiltinDeepSeekModelRef(this.modelId);

  final String modelId;

  @override
  AiProviderId get provider => AiProviderId.deepseek;

  @override
  String get bareModelId => modelId.trim();

  @override
  String get providerModelId => bareModelId;

  @override
  String? get endpointProfileId => null;

  @override
  String get storageValue => bareModelId;
}

/// Custom New API / Anthropic-compatible model on one named profile.
final class EndpointAiModelRef extends AiModelRef {
  const EndpointAiModelRef({required this.profileId, required this.modelId});

  final String profileId;
  final String modelId;

  @override
  AiProviderId get provider => AiProviderId.newApi;

  @override
  String get bareModelId => modelId.trim();

  @override
  String get providerModelId => 'newapi:$bareModelId';

  @override
  String get endpointProfileId => profileId;

  @override
  String get storageValue => 'sv1:endpoint:$profileId:$bareModelId';
}

/// Historical `newapi:<model>` value from before named profiles existed.
///
/// Execution binds this to the profile created by legacy migration, not to
/// whatever profile is currently the global default.
final class LegacyNewApiModelRef extends AiModelRef {
  const LegacyNewApiModelRef(this.modelId);

  final String modelId;

  @override
  AiProviderId get provider => AiProviderId.newApi;

  @override
  String get bareModelId => modelId.trim();

  @override
  String get providerModelId => 'newapi:$bareModelId';

  @override
  String? get endpointProfileId => null;

  @override
  String get storageValue => 'newapi:$bareModelId';
}

/// Bare model id from a New API storage value, a legacy prefix, or plain text.
String newApiBareModelId(String raw) {
  final parsed = AiModelRef.parse(raw);
  if (parsed is EndpointAiModelRef || parsed is LegacyNewApiModelRef) {
    return parsed.bareModelId;
  }
  final trimmed = raw.trim();
  if (trimmed.startsWith('newapi:')) return trimmed.substring(7).trim();
  return trimmed;
}
