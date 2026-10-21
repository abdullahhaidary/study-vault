import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../pdf_ai_materials/domain/pdf_ai_generation_progress.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../domain/ai_generation_models.dart';

/// Device-local CRUD for [local_ai_generation_jobs]. The table is created in
/// [AppDatabase] beforeOpen and is not part of the synced schema.
class AiGenerationJobRepository {
  AiGenerationJobRepository(this._db);

  final AppDatabase _db;

  static const _active = [
    'queued',
    'running',
    'waiting_to_retry',
    'cancel_requested',
  ];

  Future<List<AiGenerationJob>> listAll() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM local_ai_generation_jobs ORDER BY created_at ASC, id ASC',
        )
        .get();
    return [for (final row in rows) _job(row)];
  }

  Future<AiGenerationJob?> byId(String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM local_ai_generation_jobs WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _job(row);
  }

  Future<AiGenerationJob?> activeFor({
    required String materialId,
    required PdfAiMaterialType type,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM local_ai_generation_jobs '
          'WHERE material_id = ? AND material_type = ? '
          'AND status IN (${_active.map((_) => '?').join(', ')}) '
          'AND superseded_by_job_id IS NULL '
          'ORDER BY created_at ASC LIMIT 1',
          variables: [
            Variable.withString(materialId),
            Variable.withString(type.storageValue),
            for (final status in _active) Variable.withString(status),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _job(row);
  }

  Future<AiGenerationJob?> nextQueued() async {
    final row = await _db
        .customSelect(
          'SELECT * FROM local_ai_generation_jobs WHERE status = ? '
          'ORDER BY created_at ASC, id ASC LIMIT 1',
          variables: [
            Variable.withString(AiGenerationJobStatus.queued.storageValue),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _job(row);
  }

  Future<String?> lessonIdFor(String materialId) async {
    final row = await _db
        .customSelect(
          'SELECT lesson_id FROM lesson_materials WHERE id = ?',
          variables: [Variable.withString(materialId)],
        )
        .getSingleOrNull();
    return row?.read<String>('lesson_id');
  }

  Future<void> save(AiGenerationJob job) {
    return _db.customStatement(
      'INSERT OR REPLACE INTO local_ai_generation_jobs ('
      'id, operation_kind, material_id, lesson_id, title, file_path, '
      'material_type, provider, requested_model, resolved_model, thinking_mode, '
      'endpoint_profile_id, status, phase, progress_current, progress_total, '
      'attempt_count, partial_output, checkpoint_json, request_json, '
      'result_material_id, error_message, error_category, parent_job_id, '
      'superseded_by_job_id, warning_message, created_at, started_at, '
      'updated_at, completed_at'
      ') VALUES (${List.filled(30, '?').join(', ')})',
      [
        job.id,
        job.operationKind.storageValue,
        job.materialId,
        job.lessonId,
        job.title,
        job.filePath,
        job.materialType.storageValue,
        job.provider,
        job.requestedModelId,
        job.resolvedModelId,
        job.thinkingMode,
        job.endpointProfileId,
        job.status.storageValue,
        job.phase.storageValue,
        job.progressCurrent,
        job.progressTotal,
        job.attemptCount,
        job.partialOutput,
        job.checkpoint == null ? null : jsonEncode(job.checkpoint!.toJson()),
        jsonEncode(job.request.toJson()),
        job.resultMaterialId,
        job.errorMessage,
        job.errorCategory?.storageValue,
        job.parentJobId,
        job.supersededByJobId,
        job.warningMessage,
        job.createdAt.millisecondsSinceEpoch,
        job.startedAt?.millisecondsSinceEpoch,
        job.updatedAt.millisecondsSinceEpoch,
        job.completedAt?.millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> delete(String id) {
    return _db.customStatement(
      'DELETE FROM local_ai_generation_jobs WHERE id = ?',
      [id],
    );
  }

  Future<void> clearCompleted() {
    return _db.customStatement(
      'DELETE FROM local_ai_generation_jobs WHERE status IN (?, ?)',
      [
        AiGenerationJobStatus.completed.storageValue,
        AiGenerationJobStatus.completedWithWarning.storageValue,
      ],
    );
  }

  Future<void> markEndpointProfileUnavailable(String profileId, DateTime now) {
    final millis = now.millisecondsSinceEpoch;
    return _db.customStatement(
      'UPDATE local_ai_generation_jobs SET status = ?, phase = ?, '
      'error_category = ?, error_message = ?, updated_at = ?, completed_at = ? '
      'WHERE endpoint_profile_id = ? AND status IN (?, ?, ?, ?)',
      [
        AiGenerationJobStatus.configurationRequired.storageValue,
        AiGenerationPhase.finished.storageValue,
        AiGenerationErrorCategory.configurationRequired.storageValue,
        'API profile unavailable. Choose another profile before retrying.',
        millis,
        millis,
        profileId,
        AiGenerationJobStatus.queued.storageValue,
        AiGenerationJobStatus.waitingToRetry.storageValue,
        AiGenerationJobStatus.running.storageValue,
        AiGenerationJobStatus.cancelRequested.storageValue,
      ],
    );
  }

  /// Queued work resumes. A killed process is never left looking in-flight.
  Future<void> recoverOnStartup(DateTime now) async {
    final millis = now.millisecondsSinceEpoch;
    await _db.customStatement(
      'UPDATE local_ai_generation_jobs SET status = ?, phase = ?, '
      'updated_at = ?, completed_at = ? '
      'WHERE status IN (?, ?) AND partial_output IS NOT NULL '
      "AND length(trim(partial_output)) > 0",
      [
        AiGenerationJobStatus.partial.storageValue,
        AiGenerationPhase.finished.storageValue,
        millis,
        millis,
        AiGenerationJobStatus.running.storageValue,
        AiGenerationJobStatus.cancelRequested.storageValue,
      ],
    );
    await _db.customStatement(
      'UPDATE local_ai_generation_jobs SET status = ?, phase = ?, '
      'error_category = ?, error_message = ?, updated_at = ?, completed_at = ? '
      'WHERE status IN (?, ?)',
      [
        AiGenerationJobStatus.interrupted.storageValue,
        AiGenerationPhase.finished.storageValue,
        AiGenerationErrorCategory.network.storageValue,
        'The app closed while this was generating. No partial response was received. Retry to continue from saved checkpoints.',
        millis,
        millis,
        AiGenerationJobStatus.running.storageValue,
        AiGenerationJobStatus.cancelRequested.storageValue,
      ],
    );
    await _db.customStatement(
      'UPDATE local_ai_generation_jobs SET status = ?, phase = ?, updated_at = ? '
      'WHERE status = ?',
      [
        AiGenerationJobStatus.queued.storageValue,
        AiGenerationPhase.waiting.storageValue,
        millis,
        AiGenerationJobStatus.waitingToRetry.storageValue,
      ],
    );
  }

  AiGenerationJob _job(QueryRow row) {
    final type = PdfAiMaterialTypeX.fromStorage(
      row.read<String>('material_type'),
    );
    final request = jsonDecode(row.read<String>('request_json'));
    final checkpointRaw = row.readNullable<String>('checkpoint_json');
    return AiGenerationJob(
      id: row.read<String>('id'),
      operationKind: AiGenerationOperationKind.fromStorage(
        row.read<String>('operation_kind'),
      ),
      materialId: row.read<String>('material_id'),
      lessonId: row.readNullable<String>('lesson_id'),
      title: row.read<String>('title'),
      filePath: row.read<String>('file_path'),
      materialType: type ?? PdfAiMaterialType.summary,
      provider: row.read<String>('provider'),
      requestedModelId: row.read<String>('requested_model'),
      resolvedModelId: row.read<String>('resolved_model'),
      thinkingMode: row.readNullable<String>('thinking_mode'),
      endpointProfileId: row.readNullable<String>('endpoint_profile_id'),
      status: AiGenerationJobStatus.fromStorage(row.read<String>('status')),
      phase: AiGenerationPhase.fromStorage(row.read<String>('phase')),
      progressCurrent: row.read<int>('progress_current'),
      progressTotal: row.read<int>('progress_total'),
      attemptCount: row.read<int>('attempt_count'),
      request: request is Map
          ? AiGenerationRequestPayload.fromJson(request.cast<String, Object?>())
          : const AiGenerationRequestPayload(),
      partialOutput: row.readNullable<String>('partial_output'),
      checkpoint: checkpointRaw == null
          ? null
          : PdfGenerationCheckpoint.fromJson(
              (jsonDecode(checkpointRaw) as Map).cast<String, Object?>(),
            ),
      resultMaterialId: row.readNullable<String>('result_material_id'),
      errorMessage: row.readNullable<String>('error_message'),
      errorCategory: AiGenerationErrorCategory.fromStorage(
        row.readNullable<String>('error_category'),
      ),
      parentJobId: row.readNullable<String>('parent_job_id'),
      supersededByJobId: row.readNullable<String>('superseded_by_job_id'),
      warningMessage: row.readNullable<String>('warning_message'),
      createdAt: _time(row.read<int>('created_at')),
      startedAt: _optionalTime(row.readNullable<int>('started_at')),
      updatedAt: _time(row.read<int>('updated_at')),
      completedAt: _optionalTime(row.readNullable<int>('completed_at')),
    );
  }

  DateTime _time(int millis) => DateTime.fromMillisecondsSinceEpoch(millis);

  DateTime? _optionalTime(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}
