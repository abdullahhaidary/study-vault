import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_generation_queue/data/ai_generation_providers.dart';
import '../../ai_generation_queue/domain/ai_generation_models.dart';
import '../../ai_generation_queue/services/ai_generation_coordinator.dart';
import '../domain/pdf_ai_material_models.dart';

Future<void> enqueuePdfMaterialGeneration({
  required BuildContext context,
  required WidgetRef ref,
  required String materialId,
  required String title,
  required String filePath,
  required PdfAiMaterialType type,
  required AiExecutionSelection selection,
  String? lessonId,
  String? customInstruction,
  String? storedInstruction,
  String? reformatSource,
  String? reuseSourceFingerprint,
  bool translateToPersian = false,
}) async {
  try {
    await ref
        .read(aiGenerationCoordinatorProvider)
        .enqueue(
          AiGenerationEnqueue(
            materialId: materialId,
            lessonId: lessonId,
            title: title,
            filePath: filePath,
            type: type,
            provider: selection.provider.storageValue,
            requestedModelId: selection.requestedModelId,
            resolvedModelId: selection.resolvedModelId,
            thinkingMode: selection.thinkingMode?.storageValue,
            endpointProfileId: selection.endpointProfileId,
            request: AiGenerationRequestPayload(
              customInstruction: customInstruction,
              storedInstruction: storedInstruction,
              reformatSource: reformatSource,
              reuseSourceFingerprint: reuseSourceFingerprint,
              translateToPersian: translateToPersian,
            ),
          ),
        );
  } on DuplicateAiGenerationException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Added to generation queue'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () =>
            appNavigatorKey.currentState?.pushNamed(AppRoutes.generationCenter),
      ),
    ),
  );
}

void openGenerationCenter({String? jobId}) {
  appNavigatorKey.currentState?.pushNamed(
    AppRoutes.generationCenter,
    arguments: jobId,
  );
}

class PdfAiQueueBanner extends ConsumerWidget {
  const PdfAiQueueBanner({
    super.key,
    required this.materialId,
    required this.type,
  });

  final String materialId;
  final PdfAiMaterialType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(
      pdfAiJobForTargetProvider((materialId: materialId, type: type)),
    );
    if (job == null || (!job.isActive && !job.needsAttention)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.isActive ? job.progressLabel : job.statusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: job.needsAttention
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          TextButton(
            onPressed: () => openGenerationCenter(jobId: job.id),
            child: const Text('View in Generation Center'),
          ),
        ],
      ),
    );
  }
}
