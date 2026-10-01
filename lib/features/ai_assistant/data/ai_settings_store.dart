import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_actions.dart';

/// Non-secret AI preferences (model, language, consent, study preference).
///
/// Stored outside Study Vault backup paths on purpose.
abstract class AiSettingsStore {
  Future<String> getModelId();
  Future<void> setModelId(String modelId);
  Future<AiLanguage> getLanguage();
  Future<void> setLanguage(AiLanguage language);
  Future<String?> getStudyPreference();
  Future<void> setStudyPreference(String? value);
  Future<bool> getPrivacyConsentAccepted();
  Future<void> setPrivacyConsentAccepted(bool accepted);

  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}

class SharedPreferencesAiSettingsStore implements AiSettingsStore {
  SharedPreferencesAiSettingsStore({SharedPreferences? prefs})
    : _prefsOverride = prefs;

  static const _modelKey = 'ai_gemini_model';
  static const _languageKey = 'ai_default_language';
  static const _preferenceKey = 'ai_study_preference';
  static const _consentKey = 'ai_privacy_consent_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ??
        (_cached ??= await SharedPreferences.getInstance());
  }

  @override
  Future<String> getModelId() async {
    final prefs = await _prefs();
    return prefs.getString(_modelKey) ?? AiModelIds.recommended;
  }

  @override
  Future<void> setModelId(String modelId) async {
    final prefs = await _prefs();
    await prefs.setString(_modelKey, modelId);
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
  Future<bool> getPrivacyConsentAccepted() async {
    final prefs = await _prefs();
    return prefs.getBool(_consentKey) ?? false;
  }

  @override
  Future<void> setPrivacyConsentAccepted(bool accepted) async {
    final prefs = await _prefs();
    await prefs.setBool(_consentKey, accepted);
  }
}

/// In-memory settings for tests.
class MemoryAiSettingsStore implements AiSettingsStore {
  String _model = AiModelIds.recommended;
  AiLanguage _language = AiLanguage.auto;
  String? _preference;
  bool _consent = false;

  @override
  Future<String> getModelId() async => _model;

  @override
  Future<void> setModelId(String modelId) async => _model = modelId;

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
  Future<bool> getPrivacyConsentAccepted() async => _consent;

  @override
  Future<void> setPrivacyConsentAccepted(bool accepted) async {
    _consent = accepted;
  }

  @override
  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}
