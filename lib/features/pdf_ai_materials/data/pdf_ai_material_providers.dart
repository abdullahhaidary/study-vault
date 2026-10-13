import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../domain/pdf_ai_material_models.dart';
import '../domain/pdf_ai_translation.dart';
import '../services/pdf_ai_material_service.dart';
import '../services/pdf_ai_translation_service.dart';
import 'pdf_ai_preferred_store.dart';

final pdfAiCompletionClientProvider = Provider<PdfAiCompletionClient>((ref) {
  return RoutingPdfAiCompletionClient(
    gemini: ref.watch(geminiAiServiceProvider),
    deepSeek: ref.watch(deepseekAiServiceProvider),
    newApi: ref.watch(newApiClaudeServiceProvider),
  );
});

final pdfAiMaterialServiceProvider = Provider<PdfAiMaterialService>((ref) {
  return PdfAiMaterialService(
    ref.watch(databaseProvider),
    ref.watch(pdfAiCompletionClientProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final pdfAiMaterialsProvider =
    StreamProvider.family<List<PdfAiMaterial>, String>((ref, materialId) {
      return ref
          .watch(pdfAiMaterialServiceProvider)
          .watchForMaterial(materialId);
    });

final pdfAiTranslationServiceProvider = Provider<PdfAiTranslationService>((
  ref,
) {
  return PdfAiTranslationService(
    ref.watch(databaseProvider),
    ref.watch(pdfAiCompletionClientProvider),
  );
});

/// Translations by source version id for one lesson material.
final pdfAiTranslationsProvider =
    StreamProvider.family<Map<String, PdfAiMaterialTranslation>, String>((
      ref,
      materialId,
    ) {
      return ref
          .watch(pdfAiTranslationServiceProvider)
          .watchForMaterial(materialId);
    });

/// Language shown in the AI materials reader; shared by every tab of a
/// material so switching Summary → Explanation keeps Persian on.
final pdfAiLanguageProvider = StateProvider.family<PdfAiLanguage, String>(
  (ref, materialId) => PdfAiLanguage.original,
);

/// "3/12" while a source version is being translated, keyed by version id.
final pdfAiTranslationProgressProvider = StateProvider.family<String?, String>(
  (ref, sourceId) => null,
);

/// Remembered choice for "Also create Persian" when generating materials.
abstract final class PdfAiAlsoPersian {
  static const key = 'pdf_ai_also_persian_v1';
}

final pdfAiAlsoPersianProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PdfAiAlsoPersian.key) ?? false;
});

final pdfAiMaterialSelectedTypeProvider =
    StateProvider.family<PdfAiMaterialType, String>((ref, materialId) {
      return PdfAiMaterialType.summary;
    });

typedef PdfAiMaterialScrollKey = ({
  String materialId,
  PdfAiMaterialType type,
  String generationId,
  PdfAiLanguage language,
});

final pdfAiMaterialScrollOffsetProvider =
    StateProvider.family<double, PdfAiMaterialScrollKey>((ref, key) => 0);

final pdfAiPreferredStoreProvider = Provider<PdfAiPreferredStore>((ref) {
  return SharedPreferencesPdfAiPreferredStore();
});

final pdfAiPreferredVersionProvider =
    FutureProvider.family<String?, PdfAiPreferredKey>((ref, key) {
      return ref.watch(pdfAiPreferredStoreProvider).read(key);
    });
