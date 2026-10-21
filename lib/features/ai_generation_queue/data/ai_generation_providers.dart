import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../pdf_ai_materials/data/pdf_ai_material_providers.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../domain/ai_generation_models.dart';
import '../services/ai_generation_coordinator.dart';
import '../services/pdf_material_generation_runner.dart';
import 'ai_generation_job_repository.dart';

final aiGenerationCoordinatorProvider = Provider<AiGenerationCoordinator>((
  ref,
) {
  final coordinator = AiGenerationCoordinator(
    repository: AiGenerationJobRepository(ref.watch(databaseProvider)),
    runner: PdfMaterialGenerationRunner(
      ref.watch(pdfAiMaterialServiceProvider),
      ref.watch(pdfAiTranslationServiceProvider),
    ),
  );
  ref.onDispose(coordinator.dispose);
  unawaited(coordinator.start());
  return coordinator;
});

final aiGenerationJobsProvider = StreamProvider<List<AiGenerationJob>>((ref) {
  return ref.watch(aiGenerationCoordinatorProvider).watchJobs();
});

final aiGenerationNoticesProvider = StreamProvider<AiGenerationNotice>((ref) {
  return ref.watch(aiGenerationCoordinatorProvider).notices;
});

final generationQueueSnapshotProvider = Provider<GenerationQueueSnapshot>((
  ref,
) {
  final jobs = ref.watch(aiGenerationJobsProvider).valueOrNull ?? const [];
  return GenerationQueueSnapshot.from(jobs);
});

typedef PdfAiJobKey = ({String materialId, PdfAiMaterialType type});

/// Newest non-superseded job for one PDF and study-material type.
final pdfAiJobForTargetProvider =
    Provider.family<AiGenerationJob?, PdfAiJobKey>((ref, key) {
      final jobs = ref.watch(aiGenerationJobsProvider).valueOrNull ?? const [];
      AiGenerationJob? latest;
      for (final job in jobs) {
        if (job.materialId == key.materialId &&
            job.materialType == key.type &&
            job.supersededByJobId == null) {
          latest = job;
        }
      }
      return latest;
    });
