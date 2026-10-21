import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../pdf_ai_materials/domain/pdf_ai_generation_progress.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../data/ai_generation_job_repository.dart';
import '../domain/ai_generation_models.dart';
import 'ai_generation_runner.dart';

class AiGenerationEnqueue {
  const AiGenerationEnqueue({
    required this.materialId,
    required this.title,
    required this.filePath,
    required this.type,
    required this.provider,
    required this.requestedModelId,
    required this.resolvedModelId,
    this.lessonId,
    this.thinkingMode,
    this.endpointProfileId,
    this.request = const AiGenerationRequestPayload(),
    this.operationKind = AiGenerationOperationKind.pdfMaterial,
    this.parentJobId,
    this.checkpoint,
    this.partialOutput,
  });

  final String materialId;
  final String? lessonId;
  final String title;
  final String filePath;
  final PdfAiMaterialType type;
  final String provider;
  final String requestedModelId;
  final String resolvedModelId;
  final String? thinkingMode;
  final String? endpointProfileId;
  final AiGenerationRequestPayload request;
  final AiGenerationOperationKind operationKind;
  final String? parentJobId;
  final PdfGenerationCheckpoint? checkpoint;
  final String? partialOutput;
}

/// App-scoped FIFO queue. At most [maxConcurrent] jobs run at once.
class AiGenerationCoordinator {
  AiGenerationCoordinator({
    required this.repository,
    required this.runner,
    this.maxConcurrent = 2,
    this.maxTransientRetries = 2,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AiGenerationJobRepository repository;
  final AiGenerationRunner runner;
  final int maxConcurrent;
  final int maxTransientRetries;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _clock;
  final Uuid _uuid;

  final _jobs = StreamController<List<AiGenerationJob>>.broadcast();
  final _notices = StreamController<AiGenerationNotice>.broadcast();
  final _cancelIds = <String>{};
  var _activeRuns = 0;
  var _started = false;
  var _chain = Future<void>.value();
  List<AiGenerationJob> current = const [];

  Stream<List<AiGenerationJob>> watchJobs() async* {
    if (current.isEmpty) {
      current = await repository.listAll();
    }
    yield current;
    yield* _jobs.stream;
  }

  Stream<AiGenerationNotice> get notices => _notices.stream;

  Future<void> start() {
    return _sync(() async {
      if (_started) return;
      _started = true;
      await repository.recoverOnStartup(_clock());
      await _publish();
      await _pump();
    });
  }

  Future<AiGenerationJob> enqueue(AiGenerationEnqueue input) {
    return _sync(() => _enqueue(input));
  }

  Future<AiGenerationJob> _enqueue(AiGenerationEnqueue input) async {
    final existing = await repository.activeFor(
      materialId: input.materialId,
      type: input.type,
    );
    if (existing != null) throw DuplicateAiGenerationException(existing);
    final now = _clock();
    final lessonId =
        input.lessonId ?? await repository.lessonIdFor(input.materialId);
    final job = AiGenerationJob(
      id: _uuid.v4(),
      operationKind: input.operationKind,
      materialId: input.materialId,
      lessonId: lessonId,
      title: input.title,
      filePath: input.filePath,
      materialType: input.type,
      provider: input.provider,
      requestedModelId: input.requestedModelId,
      resolvedModelId: input.resolvedModelId,
      thinkingMode: input.thinkingMode,
      endpointProfileId: input.endpointProfileId,
      status: AiGenerationJobStatus.queued,
      phase: AiGenerationPhase.waiting,
      progressCurrent: 0,
      progressTotal: 0,
      attemptCount: 0,
      request: input.request,
      partialOutput: input.partialOutput,
      checkpoint: input.checkpoint,
      resultMaterialId: null,
      errorMessage: null,
      errorCategory: null,
      parentJobId: input.parentJobId,
      supersededByJobId: null,
      warningMessage: null,
      createdAt: now,
      startedAt: null,
      updatedAt: now,
      completedAt: null,
    );
    await repository.save(job);
    await _publish();
    await _pump();
    return job;
  }

  Future<AiGenerationJob> retryWithSelection(
    String jobId,
    AiExecutionSelection selection,
  ) {
    return _sync(() async {
      final job = await _require(jobId);
      if (!job.canRetry && !job.needsProfileReplacement) {
        throw StateError('This job cannot be retried.');
      }
      return _child(
        job,
        kind: job.operationKind == AiGenerationOperationKind.pdfTranslation
            ? AiGenerationOperationKind.pdfTranslation
            : AiGenerationOperationKind.pdfMaterial,
        request: job.request,
        checkpoint: job.checkpoint,
        replacement: selection,
      );
    });
  }

  Future<AiGenerationJob> retry(String jobId) {
    return _sync(() async {
      final job = await _require(jobId);
      if (!job.canRetry) {
        throw StateError('This job cannot be retried.');
      }
      final child = await _child(
        job,
        kind: job.operationKind == AiGenerationOperationKind.pdfTranslation
            ? AiGenerationOperationKind.pdfTranslation
            : AiGenerationOperationKind.pdfMaterial,
        request: job.request,
        checkpoint: job.checkpoint,
      );
      return child;
    });
  }

  /// Starts a new continuation request. The provider socket itself cannot resume.
  Future<AiGenerationJob> continuePartial(String jobId) {
    return _sync(() async {
      final job = await _require(jobId);
      if (!job.canContinue) {
        throw StateError('This partial result cannot be continued.');
      }
      return _child(
        job,
        kind: AiGenerationOperationKind.continuation,
        request: AiGenerationRequestPayload(
          customInstruction: job.request.customInstruction,
          storedInstruction: job.request.storedInstruction,
          reformatSource: job.request.reformatSource,
          reuseSourceFingerprint: job.request.reuseSourceFingerprint,
          translateToPersian: job.request.translateToPersian,
          partialSeed: job.partialOutput,
          sourceVersionId: job.request.sourceVersionId,
        ),
        checkpoint: job.checkpoint,
        partialOutput: job.partialOutput,
      );
    });
  }

  Future<AiGenerationJob> retryTranslation(String jobId) {
    return _sync(() async {
      final job = await _require(jobId);
      if (!job.canRetryTranslation) {
        throw StateError('There is no translation to retry.');
      }
      return _child(
        job,
        kind: AiGenerationOperationKind.pdfTranslation,
        request: AiGenerationRequestPayload(
          translateToPersian: true,
          sourceVersionId: job.resultMaterialId,
          storedInstruction: job.request.storedInstruction,
        ),
      );
    });
  }

  Future<void> markProfileUnavailable(String profileId) {
    return _sync(() async {
      await repository.markEndpointProfileUnavailable(profileId, _clock());
      await _publish();
    });
  }

  Future<void> cancel(String jobId) {
    return _sync(() async {
      final job = await _require(jobId);
      final now = _clock();
      if (job.status == AiGenerationJobStatus.queued ||
          job.status == AiGenerationJobStatus.waitingToRetry) {
        await repository.save(
          job.copyWith(
            status: AiGenerationJobStatus.cancelled,
            phase: AiGenerationPhase.finished,
            errorCategory: AiGenerationErrorCategory.cancelled,
            errorMessage: 'Cancelled before it started.',
            updatedAt: now,
            completedAt: now,
          ),
        );
        await _publish();
        return;
      }
      if (job.status == AiGenerationJobStatus.running) {
        _cancelIds.add(jobId);
        await repository.save(
          job.copyWith(
            status: AiGenerationJobStatus.cancelRequested,
            errorMessage:
                'Stopping after the current step. A request already sent to the provider may still use tokens.',
            updatedAt: now,
          ),
        );
        await _publish();
      }
    });
  }

  Future<String> savePartial(String jobId) async {
    final job = await _require(jobId);
    if (!job.canSavePartial) {
      throw StateError('There is no partial result to save.');
    }
    final savedId = await runner.savePartial(job);
    final now = _clock();
    await repository.save(
      job.copyWith(
        status: AiGenerationJobStatus.completedWithWarning,
        phase: AiGenerationPhase.finished,
        resultMaterialId: savedId,
        warningMessage: 'Saved the partial result as a version.',
        updatedAt: now,
        completedAt: now,
      ),
    );
    await _publish();
    _announce(await _require(jobId));
    return savedId;
  }

  Future<void> discardPartial(String jobId) {
    return _sync(() async {
      final job = await _require(jobId);
      final now = _clock();
      await repository.save(
        job.copyWith(
          status: AiGenerationJobStatus.cancelled,
          phase: AiGenerationPhase.finished,
          clearPartialOutput: true,
          errorMessage: 'Partial result discarded.',
          updatedAt: now,
          completedAt: now,
        ),
      );
      await _publish();
    });
  }

  Future<void> remove(String jobId) async {
    final job = await _require(jobId);
    if (job.isActive) throw StateError('Cancel the job before removing it.');
    await repository.delete(jobId);
    await _publish();
  }

  Future<void> clearCompleted() async {
    await repository.clearCompleted();
    await _publish();
  }

  Future<void> dispose() async {
    await _jobs.close();
    await _notices.close();
  }

  Future<AiGenerationJob> _child(
    AiGenerationJob parent, {
    required AiGenerationOperationKind kind,
    required AiGenerationRequestPayload request,
    PdfGenerationCheckpoint? checkpoint,
    String? partialOutput,
    AiExecutionSelection? replacement,
  }) async {
    final child = await _enqueue(
      AiGenerationEnqueue(
        materialId: parent.materialId,
        lessonId: parent.lessonId,
        title: parent.title,
        filePath: parent.filePath,
        type: parent.materialType,
        provider: replacement?.provider.storageValue ?? parent.provider,
        requestedModelId:
            replacement?.requestedModelId ?? parent.requestedModelId,
        resolvedModelId: replacement?.resolvedModelId ?? parent.resolvedModelId,
        thinkingMode:
            replacement?.thinkingMode?.storageValue ?? parent.thinkingMode,
        endpointProfileId: replacement == null
            ? parent.endpointProfileId
            : replacement.endpointProfileId,
        request: request,
        operationKind: kind,
        parentJobId: parent.id,
        checkpoint: checkpoint,
        partialOutput: partialOutput,
      ),
    );
    final latestParent = await _require(parent.id);
    await repository.save(
      latestParent.copyWith(supersededByJobId: child.id, updatedAt: _clock()),
    );
    await _publish();
    return child;
  }

  Future<void> _pump() async {
    while (_activeRuns < maxConcurrent) {
      final next = await repository.nextQueued();
      if (next == null) return;
      final now = _clock();
      final running = next.copyWith(
        status: AiGenerationJobStatus.running,
        phase: AiGenerationPhase.extractingDocument,
        attemptCount: next.attemptCount + 1,
        startedAt: next.startedAt ?? now,
        clearCompletedAt: true,
        clearError: true,
        updatedAt: now,
      );
      await repository.save(running);
      _activeRuns++;
      await _publish();
      unawaited(_execute(running));
    }
  }

  Future<void> _execute(AiGenerationJob job) async {
    try {
      final result = await runner.run(
        job,
        AiGenerationRunControl(
          report: (update) => _onProgress(job.id, update),
          isCancelRequested: () => _cancelIds.contains(job.id),
        ),
      );
      await _sync(() => _finish(job.id, result));
    } on Object catch (error) {
      await _sync(() => _fail(job.id, error));
    }
  }

  Future<void> _onProgress(String jobId, PdfGenerationUpdate update) {
    return _sync(() async {
      final job = await repository.byId(jobId);
      if (job == null || !job.status.isActive) return;
      final now = _clock();
      final partial = update.partialText;
      final tooSoon =
          partial != null &&
          now.difference(job.updatedAt).inMilliseconds < 750 &&
          update.checkpoint == null;
      if (tooSoon) return;
      final phase = AiGenerationPhase.fromPdf(update.phase);
      await repository.save(
        job.copyWith(
          phase: phase == AiGenerationPhase.saving && update.total > 1
              ? AiGenerationPhase.translating
              : phase,
          progressCurrent: update.current,
          progressTotal: update.total,
          partialOutput: partial,
          checkpoint: update.checkpoint,
          updatedAt: now,
        ),
      );
      await _publish();
    });
  }

  Future<void> _finish(String jobId, AiGenerationRunResult result) async {
    _activeRuns = _activeRuns > 0 ? _activeRuns - 1 : 0;
    final job = await repository.byId(jobId);
    if (job == null) {
      await _pump();
      return;
    }
    final now = _clock();
    final AiGenerationJob updated = switch (result) {
      AiGenerationRunSuccess(:final resultMaterialId) => job.copyWith(
        status: AiGenerationJobStatus.completed,
        phase: AiGenerationPhase.finished,
        resultMaterialId: resultMaterialId,
        updatedAt: now,
        completedAt: now,
        clearError: true,
      ),
      AiGenerationRunWarning(:final resultMaterialId, :final message) =>
        job.copyWith(
          status: AiGenerationJobStatus.completedWithWarning,
          phase: AiGenerationPhase.finished,
          resultMaterialId: resultMaterialId,
          warningMessage: message,
          updatedAt: now,
          completedAt: now,
        ),
      AiGenerationRunPartial(
        :final markdown,
        :final message,
        :final category,
        :final checkpoint,
      ) =>
        job.copyWith(
          status: AiGenerationJobStatus.partial,
          phase: AiGenerationPhase.finished,
          partialOutput: markdown,
          checkpoint: checkpoint,
          errorMessage: message,
          errorCategory: category,
          updatedAt: now,
          completedAt: now,
        ),
      AiGenerationRunCancelled() => job.copyWith(
        status: AiGenerationJobStatus.cancelled,
        phase: AiGenerationPhase.finished,
        errorCategory: AiGenerationErrorCategory.cancelled,
        errorMessage:
            'Cancelled. A request already sent to the provider may still use tokens.',
        updatedAt: now,
        completedAt: now,
      ),
      AiGenerationRunFailure(
        :final message,
        :final category,
        :final partialMarkdown,
        :final checkpoint,
      ) =>
        await _failureJob(
          job,
          message: message,
          category: category,
          partialMarkdown: partialMarkdown,
          checkpoint: checkpoint,
          now: now,
        ),
    };
    if (updated.status != AiGenerationJobStatus.waitingToRetry) {
      await repository.save(updated);
      _cancelIds.remove(jobId);
      await _publish();
      _announce(updated);
    } else {
      _cancelIds.remove(jobId);
    }
    await _pump();
  }

  Future<AiGenerationJob> _failureJob(
    AiGenerationJob job, {
    required String message,
    required AiGenerationErrorCategory category,
    required String? partialMarkdown,
    required PdfGenerationCheckpoint? checkpoint,
    required DateTime now,
  }) async {
    final useful = partialMarkdown != null && partialMarkdown.trim().isNotEmpty;
    if (category == AiGenerationErrorCategory.configurationRequired) {
      return job.copyWith(
        status: AiGenerationJobStatus.configurationRequired,
        phase: AiGenerationPhase.finished,
        errorMessage: message,
        errorCategory: category,
        checkpoint: checkpoint,
        partialOutput: useful ? partialMarkdown : null,
        updatedAt: now,
        completedAt: now,
      );
    }
    if (useful && category == AiGenerationErrorCategory.partialResponse) {
      return job.copyWith(
        status: AiGenerationJobStatus.partial,
        phase: AiGenerationPhase.finished,
        partialOutput: partialMarkdown,
        checkpoint: checkpoint,
        errorMessage: message,
        errorCategory: category,
        updatedAt: now,
        completedAt: now,
      );
    }
    if (category.isTransient && job.attemptCount <= maxTransientRetries) {
      final waiting = job.copyWith(
        status: AiGenerationJobStatus.waitingToRetry,
        phase: AiGenerationPhase.waiting,
        errorMessage: message,
        errorCategory: category,
        checkpoint: checkpoint,
        partialOutput: useful ? partialMarkdown : null,
        updatedAt: now,
        clearCompletedAt: true,
      );
      await repository.save(waiting);
      await _publish();
      unawaited(_retryLater(job.id, job.attemptCount));
      return waiting;
    }
    final honest = useful
        ? message
        : category == AiGenerationErrorCategory.network ||
              category == AiGenerationErrorCategory.timeout
        ? '$message No partial response was received.'
        : message;
    return job.copyWith(
      status: AiGenerationJobStatus.failed,
      phase: AiGenerationPhase.finished,
      errorMessage: honest,
      errorCategory: category,
      checkpoint: checkpoint,
      partialOutput: useful ? partialMarkdown : null,
      updatedAt: now,
      completedAt: now,
    );
  }

  Future<void> _retryLater(String jobId, int attempt) async {
    final shift = attempt <= 1 ? 1 : attempt;
    final seconds = shift > 3 ? 8 : 1 << (shift - 1);
    await _delay(Duration(seconds: seconds.clamp(1, 8)));
    await _sync(() async {
      final job = await repository.byId(jobId);
      if (job == null || job.status != AiGenerationJobStatus.waitingToRetry) {
        return;
      }
      if (_cancelIds.contains(jobId)) return;
      await repository.save(
        job.copyWith(
          status: AiGenerationJobStatus.queued,
          phase: AiGenerationPhase.waiting,
          updatedAt: _clock(),
        ),
      );
      await _publish();
      await _pump();
    });
  }

  Future<void> _fail(String jobId, Object error) {
    final category = categorizeAiError(error);
    return _finish(
      jobId,
      AiGenerationRunFailure(
        message: messageForAiError(error),
        category: category,
      ),
    );
  }

  void _announce(AiGenerationJob job) {
    final notice = AiGenerationNotice.fromJob(job);
    if (notice != null && !_notices.isClosed) _notices.add(notice);
  }

  Future<void> _publish() async {
    current = await repository.listAll();
    if (!_jobs.isClosed) _jobs.add(current);
  }

  Future<AiGenerationJob> _require(String id) async {
    final job = await repository.byId(id);
    if (job == null) throw StateError('Generation job no longer exists.');
    return job;
  }

  Future<T> _sync<T>(Future<T> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.then((_) {}, onError: (_) {});
    return result;
  }
}
