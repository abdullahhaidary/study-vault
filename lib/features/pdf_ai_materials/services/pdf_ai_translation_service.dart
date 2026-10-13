import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../domain/pdf_ai_translation.dart';
import 'pdf_ai_material_service.dart';

typedef PdfAiTranslationProgress = void Function(int done, int total);

/// Creates and reads section-aligned translations of AI study materials.
class PdfAiTranslationService {
  PdfAiTranslationService(this._db, this._client, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PdfAiCompletionClient _client;
  final Uuid _uuid;
  final Set<String> _inFlight = {};

  bool isTranslating(String sourceId) => _inFlight.contains(sourceId);

  /// Latest translation per source version for one lesson material.
  Stream<Map<String, PdfAiMaterialTranslation>> watchForMaterial(
    String materialId,
  ) {
    final query = _db.select(_db.pdfAiMaterialTranslations).join([
      innerJoin(
        _db.pdfAiMaterials,
        _db.pdfAiMaterials.id.equalsExp(_db.pdfAiMaterialTranslations.sourceId),
      ),
    ])..where(_db.pdfAiMaterials.materialId.equals(materialId));
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.readTable(_db.pdfAiMaterialTranslations).sourceId: row.readTable(
            _db.pdfAiMaterialTranslations,
          ),
      },
    );
  }

  static bool isStale(
    PdfAiMaterialTranslation translation,
    PdfAiMaterial source,
  ) => translation.sourceHash != PdfAiTranslation.sourceHash(source.content);

  /// Translates [source] section by section and replaces any previous
  /// translation in the same language only after every section succeeds.
  Future<PdfAiMaterialTranslation> translate({
    required PdfAiMaterial source,
    required AiExecutionSelection selection,
    PdfAiLanguage language = PdfAiLanguage.persian,
    PdfAiTranslationProgress? onProgress,
  }) async {
    if (!_inFlight.add(source.id)) {
      throw StateError('This version is already being translated.');
    }
    try {
      final stopwatch = Stopwatch()..start();
      final segments = PdfAiTranslation.segments(source.content);
      final translated = <String>[];
      final calls = <PdfAiCompletion>[];
      onProgress?.call(0, segments.length);
      for (final segment in segments) {
        translated.add(await _translateSegment(segment, selection, calls));
        onProgress?.call(translated.length, segments.length);
      }
      stopwatch.stop();
      final usage = AiTokenUsage.merge([for (final c in calls) c.usage]);
      return await _save(
        source: source,
        language: language,
        content: PdfAiTranslation.join(translated),
        last: calls.last,
        usage: usage,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      _inFlight.remove(source.id);
    }
  }

  Future<String> _translateSegment(
    String segment,
    AiExecutionSelection selection,
    List<PdfAiCompletion> calls,
  ) async {
    if (segment.trim().isEmpty) return segment;
    final protected = PdfAiTranslation.protect(segment);
    final headings = PdfAiTranslation.headingCount(segment);
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      final completion = await _client.complete(
        messages: PdfAiTranslation.messages(
          protected.text,
          strict: attempt > 0,
        ),
        maxOutputTokens: PdfAiTranslation.segmentMaxOutputTokens,
        selection: selection,
      );
      calls.add(completion);
      try {
        final restored = protected.restore(completion.markdown.trim());
        if (restored.trim().isEmpty) {
          throw const FormatException('Empty translation.');
        }
        if (PdfAiTranslation.headingCount(restored) != headings &&
            attempt == 0) {
          throw const FormatException('Headings changed.');
        }
        return restored;
      } on FormatException catch (error) {
        lastError = error;
      }
    }
    throw StateError(
      'The AI could not keep the material structure: $lastError',
    );
  }

  Future<PdfAiMaterialTranslation> _save({
    required PdfAiMaterial source,
    required PdfAiLanguage language,
    required String content,
    required PdfAiCompletion last,
    required AiTokenUsage? usage,
    required int durationMs,
  }) {
    final table = _db.pdfAiMaterialTranslations;
    final now = DateTime.now();
    final values = PdfAiMaterialTranslationsCompanion(
      content: Value(content),
      sourceHash: Value(PdfAiTranslation.sourceHash(source.content)),
      provider: Value(last.provider),
      model: Value(last.model),
      promptTokens: Value(usage?.promptTokens),
      completionTokens: Value(usage?.completionTokens),
      totalTokens: Value(usage?.totalTokens),
      requestDurationMs: Value(durationMs),
      updatedAt: Value(now),
    );
    return _db.transaction(() async {
      final existing =
          await (_db.select(table)..where(
                (t) =>
                    t.sourceId.equals(source.id) &
                    t.language.equals(language.storageValue),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      if (existing == null) {
        await _db
            .into(table)
            .insert(
              values.copyWith(
                id: Value(id),
                sourceId: Value(source.id),
                language: Value(language.storageValue),
                createdAt: Value(now),
              ),
            );
      } else {
        await (_db.update(table)..where((t) => t.id.equals(id))).write(values);
      }
      return (_db.select(table)..where((t) => t.id.equals(id))).getSingle();
    });
  }
}
