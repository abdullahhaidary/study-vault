import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../pdf_ai_materials/domain/pdf_ai_generation_progress.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';

/// What the queue is doing. New operations can be added without a schema bump.
enum AiGenerationOperationKind {
  pdfMaterial('pdf_material'),
  continuation('continuation'),
  pdfTranslation('pdf_translation');

  const AiGenerationOperationKind(this.storageValue);
  final String storageValue;

  static AiGenerationOperationKind fromStorage(String value) {
    for (final kind in values) {
      if (kind.storageValue == value) return kind;
    }
    return pdfMaterial;
  }
}

enum AiGenerationJobStatus {
  queued('queued'),
  running('running'),
  waitingToRetry('waiting_to_retry'),
  completed('completed'),
  completedWithWarning('completed_with_warning'),
  partial('partial'),
  failed('failed'),
  cancelRequested('cancel_requested'),
  cancelled('cancelled'),
  interrupted('interrupted'),
  configurationRequired('configuration_required');

  const AiGenerationJobStatus(this.storageValue);
  final String storageValue;

  static AiGenerationJobStatus fromStorage(String value) {
    for (final status in values) {
      if (status.storageValue == value) return status;
    }
    return failed;
  }

  bool get isActive => switch (this) {
    queued || running || waitingToRetry || cancelRequested => true,
    _ => false,
  };

  bool get isTerminal => !isActive;
}

enum AiGenerationPhase {
  waiting('waiting', 'Waiting'),
  extractingDocument('extracting_document', 'Reading the document'),
  digestingChunks('digesting_chunks', 'Digesting sections'),
  synthesizing('synthesizing', 'Combining sections'),
  generatingFinalOutput(
    'generating_final_output',
    'Writing the study material',
  ),
  saving('saving', 'Saving'),
  translating('translating', 'Translating'),
  finished('finished', 'Finished');

  const AiGenerationPhase(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static AiGenerationPhase fromStorage(String value) {
    for (final phase in values) {
      if (phase.storageValue == value) return phase;
    }
    return waiting;
  }

  static AiGenerationPhase fromPdf(PdfGenerationPhase phase) => switch (phase) {
    PdfGenerationPhase.extractingDocument => extractingDocument,
    PdfGenerationPhase.digestingChunks => digestingChunks,
    PdfGenerationPhase.synthesizing => synthesizing,
    PdfGenerationPhase.generatingFinalOutput => generatingFinalOutput,
    PdfGenerationPhase.saving => saving,
  };
}

enum AiGenerationErrorCategory {
  offline('offline'),
  network('network'),
  timeout('timeout'),
  rateLimit('rate_limit'),
  server('server'),
  authentication('authentication'),
  missingFile('missing_file'),
  noExtractableText('no_extractable_text'),
  emptyResponse('empty_response'),
  malformedOutput('malformed_output'),
  partialResponse('partial_response'),
  cancelled('cancelled'),
  unknown('unknown'),
  configurationRequired('configuration_required');

  const AiGenerationErrorCategory(this.storageValue);
  final String storageValue;

  static AiGenerationErrorCategory? fromStorage(String? value) {
    if (value == null) return null;
    for (final category in values) {
      if (category.storageValue == value) return category;
    }
    return unknown;
  }

  bool get isTransient => switch (this) {
    offline || network || timeout || rateLimit || server => true,
    _ => false,
  };

  String get label => switch (this) {
    offline => 'Offline',
    network => 'Connection interrupted',
    timeout => 'Timed out',
    rateLimit => 'Rate limited',
    server => 'Provider error',
    authentication => 'AI is not configured',
    missingFile => 'Source file missing',
    noExtractableText => 'No extractable text',
    emptyResponse => 'Empty response',
    malformedOutput => 'Malformed response',
    partialResponse => 'Partial response',
    cancelled => 'Cancelled',
    unknown => 'Could not finish',
    configurationRequired => 'Choose an API profile',
  };
}

/// Versioned request body. Never include API keys or session tokens.
class AiGenerationRequestPayload {
  const AiGenerationRequestPayload({
    this.customInstruction,
    this.storedInstruction,
    this.reformatSource,
    this.reuseSourceFingerprint,
    this.translateToPersian = false,
    this.partialSeed,
    this.sourceVersionId,
  });

  static const jsonVersion = 1;

  final String? customInstruction;
  final String? storedInstruction;
  final String? reformatSource;
  final String? reuseSourceFingerprint;
  final bool translateToPersian;
  final String? partialSeed;
  final String? sourceVersionId;

  Map<String, Object?> toJson() => {
    'v': jsonVersion,
    'customInstruction': customInstruction,
    'storedInstruction': storedInstruction,
    'reformatSource': reformatSource,
    'reuseSourceFingerprint': reuseSourceFingerprint,
    'translateToPersian': translateToPersian,
    'partialSeed': partialSeed,
    'sourceVersionId': sourceVersionId,
  };

  factory AiGenerationRequestPayload.fromJson(Map<String, Object?> json) {
    return AiGenerationRequestPayload(
      customInstruction: json['customInstruction'] as String?,
      storedInstruction: json['storedInstruction'] as String?,
      reformatSource: json['reformatSource'] as String?,
      reuseSourceFingerprint: json['reuseSourceFingerprint'] as String?,
      translateToPersian: json['translateToPersian'] == true,
      partialSeed: json['partialSeed'] as String?,
      sourceVersionId: json['sourceVersionId'] as String?,
    );
  }
}

class AiGenerationJob {
  const AiGenerationJob({
    required this.id,
    required this.operationKind,
    required this.materialId,
    required this.lessonId,
    required this.title,
    required this.filePath,
    required this.materialType,
    required this.provider,
    required this.requestedModelId,
    required this.resolvedModelId,
    required this.thinkingMode,
    this.endpointProfileId,
    required this.status,
    required this.phase,
    required this.progressCurrent,
    required this.progressTotal,
    required this.attemptCount,
    required this.request,
    required this.partialOutput,
    required this.checkpoint,
    required this.resultMaterialId,
    required this.errorMessage,
    required this.errorCategory,
    required this.parentJobId,
    required this.supersededByJobId,
    required this.warningMessage,
    required this.createdAt,
    required this.startedAt,
    required this.updatedAt,
    required this.completedAt,
  });

  final String id;
  final AiGenerationOperationKind operationKind;
  final String materialId;
  final String? lessonId;
  final String title;
  final String filePath;
  final PdfAiMaterialType materialType;
  final String provider;
  final String requestedModelId;
  final String resolvedModelId;
  final String? thinkingMode;
  final String? endpointProfileId;
  final AiGenerationJobStatus status;
  final AiGenerationPhase phase;
  final int progressCurrent;
  final int progressTotal;
  final int attemptCount;
  final AiGenerationRequestPayload request;
  final String? partialOutput;
  final PdfGenerationCheckpoint? checkpoint;
  final String? resultMaterialId;
  final String? errorMessage;
  final AiGenerationErrorCategory? errorCategory;
  final String? parentJobId;
  final String? supersededByJobId;
  final String? warningMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isActive => status.isActive && supersededByJobId == null;

  bool get needsAttention =>
      supersededByJobId == null &&
      (status == AiGenerationJobStatus.failed ||
          status == AiGenerationJobStatus.partial ||
          status == AiGenerationJobStatus.interrupted ||
          status == AiGenerationJobStatus.configurationRequired);

  bool get isSuccess =>
      status == AiGenerationJobStatus.completed ||
      status == AiGenerationJobStatus.completedWithWarning;

  bool get translateToPersian => request.translateToPersian;

  AiExecutionSelection get selection => AiExecutionSelection(
    provider: AiProviderId.values.firstWhere(
      (provider) => provider.storageValue == this.provider,
      orElse: () => AiProviderId.gemini,
    ),
    requestedModelId: requestedModelId,
    resolvedModelId: resolvedModelId,
    endpointProfileId: endpointProfileId,
    thinkingMode: thinkingMode == null
        ? null
        : AiThinkingMode.values
              .where((mode) => mode.name == thinkingMode)
              .firstOrNull,
  );

  String get typeLabel => materialType.shortName;

  String get statusLabel => switch (status) {
    AiGenerationJobStatus.queued => 'Queued',
    AiGenerationJobStatus.running => 'Generating',
    AiGenerationJobStatus.waitingToRetry => 'Waiting to retry',
    AiGenerationJobStatus.completed => 'Ready',
    AiGenerationJobStatus.completedWithWarning => 'Ready with a warning',
    AiGenerationJobStatus.partial => 'Partial result',
    AiGenerationJobStatus.failed => 'Failed',
    AiGenerationJobStatus.cancelRequested => 'Cancelling',
    AiGenerationJobStatus.cancelled => 'Cancelled',
    AiGenerationJobStatus.interrupted => 'Interrupted',
    AiGenerationJobStatus.configurationRequired => 'Needs an API profile',
  };

  String get progressLabel {
    if (progressTotal > 0 &&
        (phase == AiGenerationPhase.digestingChunks ||
            phase == AiGenerationPhase.translating)) {
      return '${phase.label} $progressCurrent of $progressTotal';
    }
    return phase.label;
  }

  Duration elapsedAt(DateTime now) {
    final start = startedAt ?? createdAt;
    final end = completedAt ?? now;
    final difference = end.difference(start);
    return difference.isNegative ? Duration.zero : difference;
  }

  bool get canCancel =>
      status == AiGenerationJobStatus.queued ||
      status == AiGenerationJobStatus.running ||
      status == AiGenerationJobStatus.waitingToRetry;

  bool get needsProfileReplacement =>
      supersededByJobId == null &&
      status == AiGenerationJobStatus.configurationRequired;

  bool get canRetry =>
      supersededByJobId == null &&
      (status == AiGenerationJobStatus.failed ||
          status == AiGenerationJobStatus.interrupted);

  bool get canContinue =>
      supersededByJobId == null &&
      status == AiGenerationJobStatus.partial &&
      (partialOutput?.trim().isNotEmpty ?? false);

  bool get canRetryTranslation =>
      supersededByJobId == null &&
      status == AiGenerationJobStatus.completedWithWarning &&
      resultMaterialId != null;

  bool get canOpen => resultMaterialId != null;

  bool get canCopyPartial => partialOutput?.trim().isNotEmpty ?? false;

  bool get canSavePartial =>
      canContinue && (partialOutput?.trim().isNotEmpty ?? false);

  bool get canRemove => status.isTerminal;

  AiGenerationJob copyWith({
    AiGenerationJobStatus? status,
    AiGenerationPhase? phase,
    int? progressCurrent,
    int? progressTotal,
    int? attemptCount,
    String? partialOutput,
    bool clearPartialOutput = false,
    PdfGenerationCheckpoint? checkpoint,
    bool clearCheckpoint = false,
    String? resultMaterialId,
    String? errorMessage,
    bool clearError = false,
    AiGenerationErrorCategory? errorCategory,
    String? supersededByJobId,
    String? warningMessage,
    bool clearWarning = false,
    DateTime? startedAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return AiGenerationJob(
      id: id,
      operationKind: operationKind,
      materialId: materialId,
      lessonId: lessonId,
      title: title,
      filePath: filePath,
      materialType: materialType,
      provider: provider,
      requestedModelId: requestedModelId,
      resolvedModelId: resolvedModelId,
      thinkingMode: thinkingMode,
      endpointProfileId: endpointProfileId,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
      attemptCount: attemptCount ?? this.attemptCount,
      request: request,
      partialOutput: clearPartialOutput
          ? null
          : partialOutput ?? this.partialOutput,
      checkpoint: clearCheckpoint ? null : checkpoint ?? this.checkpoint,
      resultMaterialId: resultMaterialId ?? this.resultMaterialId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCategory: clearError ? null : errorCategory ?? this.errorCategory,
      parentJobId: parentJobId,
      supersededByJobId: supersededByJobId ?? this.supersededByJobId,
      warningMessage: clearWarning
          ? null
          : warningMessage ?? this.warningMessage,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

class DuplicateAiGenerationException implements Exception {
  const DuplicateAiGenerationException(this.existing);
  final AiGenerationJob existing;

  @override
  String toString() =>
      '${existing.typeLabel} for "${existing.title}" is already ${existing.statusLabel.toLowerCase()}.';
}

AiGenerationErrorCategory categorizeAiError(Object error) {
  final text = error.toString().toLowerCase();
  return switch (error) {
    AiProfileUnavailableException() =>
      AiGenerationErrorCategory.configurationRequired,
    AiOfflineException() => AiGenerationErrorCategory.offline,
    AiConnectionInterruptedException() => AiGenerationErrorCategory.network,
    AiTimeoutException() => AiGenerationErrorCategory.timeout,
    AiRateLimitException() => AiGenerationErrorCategory.rateLimit,
    AiServerException() ||
    AiQuotaException() => AiGenerationErrorCategory.server,
    AiNotConfiguredException() ||
    AiInvalidKeyException() ||
    AiPrivacyNotAcceptedException() ||
    AiUnsupportedModelException() => AiGenerationErrorCategory.authentication,
    AiEmptyResultException() => AiGenerationErrorCategory.emptyResponse,
    AiMalformedOutputException() => AiGenerationErrorCategory.malformedOutput,
    AiCancelledException() ||
    PdfGenerationCancelled() => AiGenerationErrorCategory.cancelled,
    StateError()
        when text.contains('no extractable text') ||
            text.contains('is empty') =>
      AiGenerationErrorCategory.noExtractableText,
    StateError() when text.contains('missing') =>
      AiGenerationErrorCategory.missingFile,
    FormatException() => AiGenerationErrorCategory.malformedOutput,
    _ when text.contains('no extractable text') =>
      AiGenerationErrorCategory.noExtractableText,
    _ when text.contains('missing on this device') =>
      AiGenerationErrorCategory.missingFile,
    _ => AiGenerationErrorCategory.unknown,
  };
}

String messageForAiError(Object error) {
  if (error is AiException) return error.message;
  if (error is PdfGenerationCancelled) {
    return 'Cancelled. A request already sent to the provider may still use tokens.';
  }
  final category = categorizeAiError(error);
  if (category == AiGenerationErrorCategory.noExtractableText) {
    return 'This PDF has no extractable text. OCR is not available yet.';
  }
  if (category == AiGenerationErrorCategory.missingFile) {
    return 'The source file is missing on this device.';
  }
  if (category != AiGenerationErrorCategory.unknown) return category.label;
  return 'Could not finish generation.';
}

class AiGenerationNotice {
  const AiGenerationNotice({
    required this.jobId,
    required this.title,
    required this.body,
    required this.action,
  });

  final String jobId;
  final String title;
  final String body;
  final AiGenerationNoticeAction action;

  static AiGenerationNotice? fromJob(AiGenerationJob job) {
    final name = '${job.typeLabel} for ${job.title}';
    return switch (job.status) {
      AiGenerationJobStatus.completed => AiGenerationNotice(
        jobId: job.id,
        title: '$name is ready',
        body: 'Open the saved version.',
        action: AiGenerationNoticeAction.open,
      ),
      AiGenerationJobStatus.completedWithWarning => AiGenerationNotice(
        jobId: job.id,
        title: '$name was saved',
        body: job.warningMessage ?? 'Translation needs another try.',
        action: AiGenerationNoticeAction.retryTranslation,
      ),
      AiGenerationJobStatus.failed => AiGenerationNotice(
        jobId: job.id,
        title: '$name failed',
        body: job.errorMessage ?? 'View details in the Generation Center.',
        action: AiGenerationNoticeAction.details,
      ),
      AiGenerationJobStatus.partial => AiGenerationNotice(
        jobId: job.id,
        title: 'Partial result available',
        body:
            '$name stopped before it finished. Continue starts a new request.',
        action: AiGenerationNoticeAction.continuePartial,
      ),
      AiGenerationJobStatus.interrupted => AiGenerationNotice(
        jobId: job.id,
        title: '$name was interrupted',
        body: 'The app restarted before this finished. Retry to continue.',
        action: AiGenerationNoticeAction.details,
      ),
      AiGenerationJobStatus.configurationRequired => AiGenerationNotice(
        jobId: job.id,
        title: '$name needs an API profile',
        body:
            'The API profile for this job is unavailable. Choose another profile to retry.',
        action: AiGenerationNoticeAction.details,
      ),
      _ => null,
    };
  }
}

enum AiGenerationNoticeAction {
  open,
  details,
  continuePartial,
  retryTranslation,
}

class GenerationQueueSnapshot {
  const GenerationQueueSnapshot({
    required this.running,
    required this.queued,
    required this.completed,
    required this.attention,
  });

  final int running;
  final int queued;
  final int completed;
  final int attention;

  bool get visible => running + queued + completed + attention > 0;

  factory GenerationQueueSnapshot.from(List<AiGenerationJob> jobs) {
    var running = 0;
    var queued = 0;
    var completed = 0;
    var attention = 0;
    for (final job in jobs) {
      if (job.supersededByJobId != null) continue;
      switch (job.status) {
        case AiGenerationJobStatus.running ||
            AiGenerationJobStatus.cancelRequested:
          running++;
        case AiGenerationJobStatus.queued ||
            AiGenerationJobStatus.waitingToRetry:
          queued++;
        case AiGenerationJobStatus.completed ||
            AiGenerationJobStatus.completedWithWarning:
          completed++;
        case AiGenerationJobStatus.failed ||
            AiGenerationJobStatus.partial ||
            AiGenerationJobStatus.interrupted ||
            AiGenerationJobStatus.configurationRequired:
          attention++;
        case AiGenerationJobStatus.cancelled:
          break;
      }
    }
    return GenerationQueueSnapshot(
      running: running,
      queued: queued,
      completed: completed,
      attention: attention,
    );
  }
}
