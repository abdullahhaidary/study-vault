import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../services/ai_service.dart';
import '../services/gemini_ai_service.dart';

final aiCredentialStoreProvider = Provider<AiCredentialStore>((ref) {
  return SecureAiCredentialStore();
});

final aiSettingsStoreProvider = Provider<AiSettingsStore>((ref) {
  return SharedPreferencesAiSettingsStore();
});

final aiServiceProvider = Provider<AiService>((ref) {
  return GeminiAiService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

/// UI-safe configured flag — never exposes the key.
final aiConfiguredProvider = FutureProvider<bool>((ref) async {
  return ref.watch(aiCredentialStoreProvider).hasApiKey;
});

final aiPrivacyConsentProvider = FutureProvider<bool>((ref) async {
  return ref.watch(aiSettingsStoreProvider).getPrivacyConsentAccepted();
});

class AiSettingsState {
  const AiSettingsState({
    required this.configured,
    required this.modelId,
    required this.language,
    required this.studyPreference,
    required this.privacyConsent,
  });

  final bool configured;
  final String modelId;
  final AiLanguage language;
  final String? studyPreference;
  final bool privacyConsent;
}

final aiSettingsStateProvider = FutureProvider<AiSettingsState>((ref) async {
  final creds = ref.watch(aiCredentialStoreProvider);
  final settings = ref.watch(aiSettingsStoreProvider);
  return AiSettingsState(
    configured: await creds.hasApiKey,
    modelId: await settings.getModelId(),
    language: await settings.getLanguage(),
    studyPreference: await settings.getStudyPreference(),
    privacyConsent: await settings.getPrivacyConsentAccepted(),
  );
});
