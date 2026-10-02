import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../domain/pdf_ai_material_models.dart';
import '../services/pdf_ai_material_service.dart';

final pdfAiCompletionClientProvider = Provider<PdfAiCompletionClient>((ref) {
  return RoutingPdfAiCompletionClient(
    gemini: ref.watch(geminiAiServiceProvider),
    deepSeek: ref.watch(deepseekAiServiceProvider),
  );
});

final pdfAiMaterialServiceProvider = Provider<PdfAiMaterialService>((ref) {
  return PdfAiMaterialService(
    ref.watch(databaseProvider),
    ref.watch(pdfAiCompletionClientProvider),
  );
});

final pdfAiMaterialsProvider =
    StreamProvider.family<List<PdfAiMaterial>, String>((ref, materialId) {
      return ref
          .watch(pdfAiMaterialServiceProvider)
          .watchForMaterial(materialId);
    });

final pdfAiMaterialSelectedTypeProvider =
    StateProvider.family<PdfAiMaterialType, String>((ref, materialId) {
      return PdfAiMaterialType.summary;
    });

typedef PdfAiMaterialScrollKey = ({
  String materialId,
  PdfAiMaterialType type,
  String generationId,
});

final pdfAiMaterialScrollOffsetProvider =
    StateProvider.family<double, PdfAiMaterialScrollKey>((ref, key) => 0);
