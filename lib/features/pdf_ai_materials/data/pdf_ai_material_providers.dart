import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../services/pdf_ai_material_service.dart';

final pdfAiCompletionClientProvider = Provider<PdfAiCompletionClient>((ref) {
  return DeepSeekPdfAiCompletionClient(
    ref.watch(deepseekAiServiceProvider),
    ref.watch(aiSettingsStoreProvider),
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

typedef PdfFingerprintInput = ({String title, String filePath});

final pdfSourceFingerprintProvider =
    FutureProvider.family<String, PdfFingerprintInput>((ref, input) {
      return ref
          .watch(pdfAiMaterialServiceProvider)
          .sourceFingerprint(title: input.title, filePath: input.filePath);
    });
