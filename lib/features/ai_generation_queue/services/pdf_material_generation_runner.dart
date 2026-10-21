import '../../ai_assistant/domain/ai_models.dart';
import '../../pdf_ai_materials/domain/pdf_ai_generation_progress.dart';
import '../../pdf_ai_materials/services/pdf_ai_material_service.dart';
import '../../pdf_ai_materials/services/pdf_ai_translation_service.dart';
import '../domain/ai_generation_models.dart';
import 'ai_generation_runner.dart';

class PdfMaterialGenerationRunner implements AiGenerationRunner {
  PdfMaterialGenerationRunner(this._materials, this._translations);

  final PdfAiMaterialService _materials;
  final PdfAiTranslationService _translations;

  @override
  Future<AiGenerationRunResult> run(
    AiGenerationJob job,
    AiGenerationRunControl control,
  ) async {
    if (job.operationKind == AiGenerationOperationKind.pdfTranslation) {
      return _translate(job, control);
    }
    final request = job.request;
    final result = await _materials.generateTracked(
      materialId: job.materialId,
      title: job.title,
      filePath: job.filePath,
      type: job.materialType,
      selection: job.selection,
      customInstruction: request.customInstruction,
      storedInstruction: request.storedInstruction,
      reformatSource: request.reformatSource,
      reuseSourceFingerprint: request.reuseSourceFingerprint,
      resume: job.checkpoint,
      continueAfter: job.operationKind == AiGenerationOperationKind.continuation
          ? request.partialSeed
          : null,
      onProgress: control.report,
      isCancelled: control.isCancelRequested,
    );
    if (control.isCancelRequested()) return const AiGenerationRunCancelled();
    if (result.mergeNeedsReview) {
      return AiGenerationRunPartial(
        markdown: result.partialMarkdown ?? '',
        message:
            result.reviewMessage ??
            'The continuation could not be joined safely. Preview it before saving.',
        category: AiGenerationErrorCategory.partialResponse,
        checkpoint: result.checkpoint,
      );
    }
    if (result.disposition != AiCompletionDisposition.complete) {
      final interrupted =
          result.disposition == AiCompletionDisposition.partialConnection;
      return AiGenerationRunPartial(
        markdown: result.partialMarkdown ?? '',
        message: interrupted
            ? 'The connection dropped before the answer finished. '
                  'Continue starts a new request from this partial text. '
                  'Tokens may already have been used.'
            : 'The request timed out before the answer finished. '
                  'Continue starts a new request from this partial text.',
        category: AiGenerationErrorCategory.partialResponse,
        checkpoint: result.checkpoint,
      );
    }
    final saved = result.saved;
    if (saved == null) {
      return const AiGenerationRunFailure(
        message: 'The AI returned an empty study material.',
        category: AiGenerationErrorCategory.emptyResponse,
      );
    }
    if (request.translateToPersian) {
      try {
        await control.report(
          const PdfGenerationUpdate(
            phase: PdfGenerationPhase.saving,
            current: 1,
            total: 1,
          ),
        );
        await _translations.translate(
          source: saved,
          selection: job.selection,
          onProgress: (done, total) {
            control.report(
              PdfGenerationUpdate(
                phase: PdfGenerationPhase.saving,
                current: done,
                total: total,
              ),
            );
          },
        );
      } on Object catch (error) {
        return AiGenerationRunWarning(
          resultMaterialId: saved.id,
          message:
              'The ${job.typeLabel} was saved, but Persian translation failed. '
              '${messageForAiError(error)}',
        );
      }
    }
    return AiGenerationRunSuccess(resultMaterialId: saved.id);
  }

  Future<AiGenerationRunResult> _translate(
    AiGenerationJob job,
    AiGenerationRunControl control,
  ) async {
    final sourceId = job.request.sourceVersionId;
    if (sourceId == null) {
      return const AiGenerationRunFailure(
        message: 'There is no saved version to translate.',
        category: AiGenerationErrorCategory.unknown,
      );
    }
    final materials = await _materials.history(
      materialId: job.materialId,
      type: job.materialType,
    );
    final source = materials.where((item) => item.id == sourceId).firstOrNull;
    if (source == null) {
      return const AiGenerationRunFailure(
        message: 'The saved version to translate is no longer available.',
        category: AiGenerationErrorCategory.missingFile,
      );
    }
    await _translations.translate(
      source: source,
      selection: job.selection,
      onProgress: (done, total) {
        control.report(
          PdfGenerationUpdate(
            phase: PdfGenerationPhase.saving,
            current: done,
            total: total,
          ),
        );
      },
    );
    return AiGenerationRunSuccess(resultMaterialId: source.id);
  }

  @override
  Future<String> savePartial(AiGenerationJob job) async {
    final text = job.partialOutput?.trim() ?? '';
    if (text.isEmpty) {
      throw StateError('There is no partial text to save.');
    }
    final saved = await _materials.saveProvidedMarkdown(
      materialId: job.materialId,
      type: job.materialType,
      content: text,
      provider: job.provider,
      model: job.resolvedModelId,
      sourceFingerprint: job.checkpoint?.sourceFingerprint,
      customInstruction: job.request.storedInstruction,
    );
    return saved.id;
  }
}
