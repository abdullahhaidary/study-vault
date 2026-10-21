import '../../pdf_ai_materials/domain/pdf_ai_generation_progress.dart';
import '../domain/ai_generation_models.dart';

class AiGenerationRunControl {
  const AiGenerationRunControl({
    required this.report,
    required this.isCancelRequested,
  });

  final Future<void> Function(PdfGenerationUpdate update) report;
  final bool Function() isCancelRequested;
}

sealed class AiGenerationRunResult {
  const AiGenerationRunResult();
}

class AiGenerationRunSuccess extends AiGenerationRunResult {
  const AiGenerationRunSuccess({required this.resultMaterialId});
  final String resultMaterialId;
}

class AiGenerationRunWarning extends AiGenerationRunResult {
  const AiGenerationRunWarning({
    required this.resultMaterialId,
    required this.message,
  });
  final String resultMaterialId;
  final String message;
}

class AiGenerationRunPartial extends AiGenerationRunResult {
  const AiGenerationRunPartial({
    required this.markdown,
    required this.message,
    required this.category,
    this.checkpoint,
  });
  final String markdown;
  final String message;
  final AiGenerationErrorCategory category;
  final PdfGenerationCheckpoint? checkpoint;
}

class AiGenerationRunFailure extends AiGenerationRunResult {
  const AiGenerationRunFailure({
    required this.message,
    required this.category,
    this.partialMarkdown,
    this.checkpoint,
  });
  final String message;
  final AiGenerationErrorCategory category;
  final String? partialMarkdown;
  final PdfGenerationCheckpoint? checkpoint;
}

class AiGenerationRunCancelled extends AiGenerationRunResult {
  const AiGenerationRunCancelled();
}

abstract interface class AiGenerationRunner {
  Future<AiGenerationRunResult> run(
    AiGenerationJob job,
    AiGenerationRunControl control,
  );

  Future<String> savePartial(AiGenerationJob job);
}
