import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_style_memory.dart';
import '../domain/annotation_ai_history.dart';
import '../services/ai_service.dart';
import '../services/annotation_ai_history_service.dart';
import '../services/annotation_ai_service.dart';
import '../services/deepseek_ai_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/new_api_claude_service.dart';
import '../services/routing_ai_service.dart';

export 'voice_input_providers.dart' show voiceInputServiceProvider;

final aiCredentialStoreProvider = Provider<AiCredentialStore>((ref) {
  return SecureAiCredentialStore();
});

final aiSettingsStoreProvider = Provider<AiSettingsStore>((ref) {
  return SharedPreferencesAiSettingsStore();
});

final geminiAiServiceProvider = Provider<GeminiAiService>((ref) {
  return GeminiAiService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final deepseekAiServiceProvider = Provider<DeepSeekAiService>((ref) {
  return DeepSeekAiService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final newApiClaudeServiceProvider = Provider<NewApiClaudeService>((ref) {
  return NewApiClaudeService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

/// Active study AI — routes to the selected provider from Settings.
final aiServiceProvider = Provider<AiService>((ref) {
  return RoutingAiService(
    settings: ref.watch(aiSettingsStoreProvider),
    gemini: ref.watch(geminiAiServiceProvider),
    deepseek: ref.watch(deepseekAiServiceProvider),
    newApi: ref.watch(newApiClaudeServiceProvider),
  );
});

/// Annotation/selection façade over [aiServiceProvider].
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

/// UI-safe configured flag for the *active* provider — never exposes the key.
final aiConfiguredProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(aiSettingsStoreProvider);
  final creds = ref.watch(aiCredentialStoreProvider);
  final provider = await settings.getProvider();
  if (provider == AiProviderId.newApi) {
    return ref.watch(newApiClaudeServiceProvider).isConfigured;
  }
  return creds.hasApiKeyFor(provider);
});

final aiPrivacyConsentProvider = FutureProvider<bool>((ref) async {
  return ref.watch(aiSettingsStoreProvider).getPrivacyConsentAccepted();
});

class AiSettingsState {
  const AiSettingsState({
    required this.provider,
    required this.configured,
    required this.modelId,
    required this.thinkingMode,
    required this.language,
    required this.styleMemoryItems,
    required this.geminiRetryCount,
    required this.privacyConsent,
    required this.geminiConfigured,
    required this.geminiKeyCount,
    required this.geminiKeySuffixes,
    required this.deepseekConfigured,
    required this.newApiConfigured,
    required this.newApiBaseUrl,
  });

  final AiProviderId provider;
  final bool configured;
  final String modelId;
  final AiThinkingMode thinkingMode;
  final AiLanguage language;
  final List<AiStyleMemoryItem> styleMemoryItems;
  final int geminiRetryCount;
  final bool privacyConsent;
  final bool geminiConfigured;
  final int geminiKeyCount;
  final List<String> geminiKeySuffixes;
  final bool deepseekConfigured;
  final bool newApiConfigured;
  final String newApiBaseUrl;

  AiProviderCapabilities get capabilities =>
      AiProviderCapabilities.forProvider(provider);
}

final aiSettingsStateProvider = FutureProvider<AiSettingsState>((ref) async {
  final creds = ref.watch(aiCredentialStoreProvider);
  final settings = ref.watch(aiSettingsStoreProvider);
  final provider = await settings.getProvider();
  return AiSettingsState(
    provider: provider,
    configured: await creds.hasApiKeyFor(provider),
    modelId: await settings.getModelIdFor(provider),
    thinkingMode: await settings.getThinkingMode(),
    language: await settings.getLanguage(),
    styleMemoryItems: await settings.getStyleMemoryItems(),
    geminiRetryCount: await settings.getGeminiRetryCount(),
    privacyConsent: await settings.getPrivacyConsentAccepted(),
    geminiConfigured: await creds.hasApiKeyFor(AiProviderId.gemini),
    geminiKeyCount: (await creds.readApiKeysFor(AiProviderId.gemini)).length,
    geminiKeySuffixes: await creds.readApiKeySuffixesFor(AiProviderId.gemini),
    deepseekConfigured: await creds.hasApiKeyFor(AiProviderId.deepseek),
    newApiConfigured: await creds.hasApiKeyFor(AiProviderId.newApi),
    newApiBaseUrl: await settings.getNewApiBaseUrl(),
  );
});
