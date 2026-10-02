import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/annotation_ai_history.dart';
import '../services/ai_service.dart';
import '../services/annotation_ai_history_service.dart';
import '../services/annotation_ai_service.dart';
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

/// Annotation/selection façade over [aiServiceProvider] (shared Gemini client).
final annotationAiServiceProvider = Provider<AnnotationAiService>((ref) {
  return AnnotationAiService(aiService: ref.watch(aiServiceProvider));
});

/// Persistent generation history for annotation AI actions.
final annotationAiHistoryServiceProvider = Provider<AnnotationAiHistoryService>(
  (ref) {
    return AnnotationAiHistoryService(
      db: ref.watch(databaseProvider),
      aiService: ref.watch(annotationAiServiceProvider),
    );
  },
);

/// Lightweight badge counts for a source fingerprint (no response bodies).
final annotationAiGenerationCountsProvider =
    FutureProvider.family<Map<AiStudyAction, int>, String>((
      ref,
      fingerprint,
    ) async {
      return ref
          .watch(annotationAiHistoryServiceProvider)
          .getGenerationCounts(sourceFingerprint: fingerprint);
    });

/// Helper to build a fingerprint from common UI fields.
String annotationAiFingerprint({
  String? annotationId,
  String? materialId,
  int? pageNumber,
  required String inputText,
}) {
  return AnnotationAiSourceFingerprint.from(
    annotationId: annotationId,
    materialId: materialId,
    pageNumber: pageNumber,
    inputText: inputText,
  );
}

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
