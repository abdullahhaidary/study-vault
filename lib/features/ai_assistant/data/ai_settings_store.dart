import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_actions.dart';
import '../domain/ai_provider.dart';
import '../domain/deepseek_model_registry.dart';
import '../domain/gemini_model_registry.dart';

/// Non-secret AI preferences (provider, model, language, consent, thinking).
///
/// Stored outside Study Vault backup paths on purpose. API keys stay in
/// secure storage, not here.
abstract class AiSettingsStore {
  static const defaultGeminiRetryCount = 3;
  static const maxGeminiRetryCount = 5;

  Future<AiProviderId> getProvider();
  Future<void> setProvider(AiProviderId provider);

  /// Model id for the currently selected provider.
  Future<String> getModelId();
  Future<void> setModelId(String modelId);

  Future<String> getModelIdFor(AiProviderId provider);
  Future<void> setModelIdFor(AiProviderId provider, String modelId);
  Future<String> getNewApiBaseUrl();
  Future<void> setNewApiBaseUrl(String url);

  Future<AiThinkingMode> getThinkingMode();
  Future<void> setThinkingMode(AiThinkingMode mode);

  Future<AiLanguage> getLanguage();
  Future<void> setLanguage(AiLanguage language);
  Future<String?> getStudyPreference();
  Future<void> setStudyPreference(String? value);
  Future<int> getGeminiRetryCount();
  Future<void> setGeminiRetryCount(int count);
  Future<bool> getPrivacyConsentAccepted();
  Future<void> setPrivacyConsentAccepted(bool accepted);

  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}

class SharedPreferencesAiSettingsStore implements AiSettingsStore {
  SharedPreferencesAiSettingsStore({SharedPreferences? prefs})
    : _prefsOverride = prefs;

  static const _providerKey = 'ai_provider';
  static const _geminiModelKey = 'ai_gemini_model';
  static const _deepseekModelKey = 'ai_deepseek_model';
  static const _newApiModelKey = 'ai_newapi_model';
  static const _newApiBaseUrlKey = 'ai_newapi_base_url';
  static const _thinkingKey = 'ai_deepseek_thinking';
  static const _languageKey = 'ai_default_language';
  static const _preferenceKey = 'ai_study_preference';
  static const _geminiRetryCountKey = 'ai_gemini_retry_count';
  static const _consentKey = 'ai_privacy_consent_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ??
        (_cached ??= await SharedPreferences.getInstance());
  }

  @override
  Future<AiProviderId> getProvider() async {
    final prefs = await _prefs();
    return AiProviderIdX.fromStorage(prefs.getString(_providerKey));
  }

  @override
  Future<void> setProvider(AiProviderId provider) async {
    final prefs = await _prefs();
    await prefs.setString(_providerKey, provider.storageValue);
  }

  @override
  Future<String> getModelId() async {
    final provider = await getProvider();
    return getModelIdFor(provider);
  }

  @override
  Future<void> setModelId(String modelId) async {
    final provider = await getProvider();
    await setModelIdFor(provider, modelId);
  }

  @override
  Future<String> getModelIdFor(AiProviderId provider) async {
    final prefs = await _prefs();
    return switch (provider) {
      AiProviderId.gemini => GeminiModelRegistry.normalize(
        prefs.getString(_geminiModelKey),
      ),
      AiProviderId.deepseek => _normalizeDeepSeekStored(
        prefs.getString(_deepseekModelKey),
      ),
      AiProviderId.newApi => normalizeNewApiModelId(
        prefs.getString(_newApiModelKey),
      ),
    };
  }

  @override
  Future<void> setModelIdFor(AiProviderId provider, String modelId) async {
    final prefs = await _prefs();
    switch (provider) {
      case AiProviderId.gemini:
        await prefs.setString(
          _geminiModelKey,
          GeminiModelRegistry.normalize(modelId),
        );
      case AiProviderId.deepseek:
        await prefs.setString(
          _deepseekModelKey,
          _normalizeDeepSeekStored(modelId),
        );
      case AiProviderId.newApi:
        await prefs.setString(_newApiModelKey, normalizeNewApiModelId(modelId));
    }
  }

  @override
  Future<String> getNewApiBaseUrl() async =>
      (await _prefs()).getString(_newApiBaseUrlKey) ?? '';

  @override
  Future<void> setNewApiBaseUrl(String url) async {
    final prefs = await _prefs();
    await prefs.setString(_newApiBaseUrlKey, normalizeNewApiBaseUrl(url));
  }

  String _normalizeDeepSeekStored(String? raw) {
    if (DeepSeekModelIds.isAuto(raw)) return DeepSeekModelIds.auto;
    return DeepSeekModelRegistry.normalize(raw);
  }

  @override
  Future<AiThinkingMode> getThinkingMode() async {
    final prefs = await _prefs();
    return AiThinkingModeX.fromStorage(prefs.getString(_thinkingKey));
  }

  @override
  Future<void> setThinkingMode(AiThinkingMode mode) async {
    final prefs = await _prefs();
    await prefs.setString(_thinkingKey, mode.storageValue);
  }

  @override
  Future<AiLanguage> getLanguage() async {
    final prefs = await _prefs();
    return AiLanguageX.fromStorage(prefs.getString(_languageKey));
  }

  @override
  Future<void> setLanguage(AiLanguage language) async {
    final prefs = await _prefs();
    await prefs.setString(_languageKey, language.storageValue);
  }

  @override
  Future<String?> getStudyPreference() async {
    final prefs = await _prefs();
    final value = prefs.getString(_preferenceKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> setStudyPreference(String? value) async {
    final prefs = await _prefs();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_preferenceKey);
    } else {
      await prefs.setString(_preferenceKey, trimmed);
    }
  }

  @override
  Future<int> getGeminiRetryCount() async {
    final prefs = await _prefs();
    return (prefs.getInt(_geminiRetryCountKey) ??
            AiSettingsStore.defaultGeminiRetryCount)
        .clamp(0, AiSettingsStore.maxGeminiRetryCount)
        .toInt();
  }

  @override
  Future<void> setGeminiRetryCount(int count) async {
    final prefs = await _prefs();
    await prefs.setInt(
      _geminiRetryCountKey,
      count.clamp(0, AiSettingsStore.maxGeminiRetryCount).toInt(),
    );
  }

  @override
  Future<bool> getPrivacyConsentAccepted() async {
    final prefs = await _prefs();
    return prefs.getBool(_consentKey) ?? false;
  }

  @override
  Future<void> setPrivacyConsentAccepted(bool accepted) async {
    final prefs = await _prefs();
    await prefs.setBool(_consentKey, accepted);
  }

  @override
  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}

String normalizeNewApiModelId(String? raw) {
  final id = raw?.trim() ?? '';
  return 'newapi:${id.startsWith('newapi:') ? id.substring(7) : id}';
}

String normalizeNewApiBaseUrl(String raw) {
  final url = raw.trim().replaceAll(RegExp(r'/+$'), '');
  if (url.isEmpty) return '';
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.host == 'docs.newapi.pro' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.endsWith('/messages')) {
    throw const FormatException(
      'Enter your HTTPS New API server URL (not docs.newapi.pro, without /messages).',
    );
  }
  return url;
}

/// In-memory settings for tests.
class MemoryAiSettingsStore implements AiSettingsStore {
  AiProviderId _provider = AiProviderId.gemini;
  String _geminiModel = GeminiModelRegistry.defaultModelId;
  String _deepseekModel = DeepSeekModelRegistry.defaultModelId;
  String _newApiModel = 'newapi:';
  String _newApiBaseUrl = '';
  AiThinkingMode _thinking = AiThinkingMode.auto;
  AiLanguage _language = AiLanguage.auto;
  String? _preference;
  int _geminiRetryCount = AiSettingsStore.defaultGeminiRetryCount;
  bool _consent = false;

  @override
  Future<AiProviderId> getProvider() async => _provider;

  @override
  Future<void> setProvider(AiProviderId provider) async => _provider = provider;

  @override
  Future<String> getModelId() async => getModelIdFor(_provider);

  @override
  Future<void> setModelId(String modelId) async =>
      setModelIdFor(_provider, modelId);

  @override
  Future<String> getModelIdFor(AiProviderId provider) async =>
      switch (provider) {
        AiProviderId.gemini => _geminiModel,
        AiProviderId.deepseek => _deepseekModel,
        AiProviderId.newApi => _newApiModel,
      };

  @override
  Future<void> setModelIdFor(AiProviderId provider, String modelId) async {
    switch (provider) {
      case AiProviderId.gemini:
        _geminiModel = GeminiModelRegistry.normalize(modelId);
      case AiProviderId.deepseek:
        _deepseekModel = DeepSeekModelIds.isAuto(modelId)
            ? DeepSeekModelIds.auto
            : DeepSeekModelRegistry.normalize(modelId);
      case AiProviderId.newApi:
        _newApiModel = normalizeNewApiModelId(modelId);
    }
  }

  @override
  Future<String> getNewApiBaseUrl() async => _newApiBaseUrl;

  @override
  Future<void> setNewApiBaseUrl(String url) async =>
      _newApiBaseUrl = normalizeNewApiBaseUrl(url);

  @override
  Future<AiThinkingMode> getThinkingMode() async => _thinking;

  @override
  Future<void> setThinkingMode(AiThinkingMode mode) async => _thinking = mode;

  @override
  Future<AiLanguage> getLanguage() async => _language;

  @override
  Future<void> setLanguage(AiLanguage language) async => _language = language;

  @override
  Future<String?> getStudyPreference() async => _preference;

  @override
  Future<void> setStudyPreference(String? value) async {
    final trimmed = value?.trim();
    _preference = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<int> getGeminiRetryCount() async => _geminiRetryCount;

  @override
  Future<void> setGeminiRetryCount(int count) async {
    _geminiRetryCount = count
        .clamp(0, AiSettingsStore.maxGeminiRetryCount)
        .toInt();
  }

  @override
  Future<bool> getPrivacyConsentAccepted() async => _consent;

  @override
  Future<void> setPrivacyConsentAccepted(bool accepted) async {
    _consent = accepted;
  }

  @override
  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}

/// Snapshot used when persisting a generation (provider + resolved model).
class AiGenerationMeta {
  const AiGenerationMeta({required this.provider, required this.modelId});

  final AiProviderId provider;
  final String modelId;

  String get providerStorage => provider.storageValue;
}

Future<AiGenerationMeta> readAiGenerationMeta(
  AiSettingsStore settings, {
  AiStudyAction? action,
}) async {
  final provider = await settings.getProvider();
  final stored = await settings.getModelIdFor(provider);
  return AiGenerationMeta(
    provider: provider,
    modelId: resolveActiveModelId(
      provider: provider,
      storedModelId: stored,
      action: action,
    ),
  );
}

/// Resolves the concrete model id used for a request (expands Auto).
String resolveActiveModelId({
  required AiProviderId provider,
  required String storedModelId,
  required AiStudyAction? action,
}) {
  switch (provider) {
    case AiProviderId.newApi:
      return normalizeNewApiModelId(storedModelId);
    case AiProviderId.gemini:
      return GeminiModelRegistry.normalize(storedModelId);
    case AiProviderId.deepseek:
      if (DeepSeekModelIds.isAuto(storedModelId)) {
        final preferPro = switch (action) {
          AiStudyAction.generateQuestions ||
          AiStudyAction.generateFlashcards ||
          AiStudyAction.createAnnotation ||
          AiStudyAction.customPrompt ||
          AiStudyAction.examPoints => true,
          _ => false,
        };
        return DeepSeekModelRegistry.resolveAuto(preferPro: preferPro);
      }
      return DeepSeekModelRegistry.normalize(storedModelId);
  }
}
