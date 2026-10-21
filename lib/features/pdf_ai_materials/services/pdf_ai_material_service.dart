import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/services/new_api_claude_service.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/services/deepseek_ai_service.dart';
import '../../ai_assistant/services/gemini_ai_service.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/services/pdf_text_extractor.dart';
import '../../lessons/data/lesson_summary_repository.dart';
import '../../lessons/data/material_mime.dart';
import '../domain/pdf_ai_generation_progress.dart';
import '../domain/pdf_ai_material_models.dart';

class PdfAiCompletion {
  const PdfAiCompletion({
    required this.markdown,
    required this.provider,
    required this.model,
    this.usage,
    this.disposition = AiCompletionDisposition.complete,
  });

  final String markdown;
  final String provider;
  final String model;
  final AiTokenUsage? usage;
  final AiCompletionDisposition disposition;

  bool get isPartial => disposition != AiCompletionDisposition.complete;
}

abstract interface class PdfAiCompletionClient {
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  });
}

/// Routes document completions to Gemini or DeepSeek from [selection].
class RoutingPdfAiCompletionClient implements PdfAiCompletionClient {
  RoutingPdfAiCompletionClient({
    required GeminiAiService gemini,
    required DeepSeekAiService deepSeek,
    NewApiClaudeService? newApi,
  }) : _gemini = gemini,
       _deepSeek = deepSeek,
       _newApi = newApi;

  final GeminiAiService _gemini;
  final DeepSeekAiService _deepSeek;
  final NewApiClaudeService? _newApi;

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) async {
    final result = switch (selection.provider) {
      AiProviderId.gemini => await _gemini.completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
      ),
      AiProviderId.deepseek => await _deepSeek.completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
      ),
      AiProviderId.newApi => await _newApi!.completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
        onPartialText: onPartialText,
      ),
    };
    return PdfAiCompletion(
      markdown: result.markdown,
      provider: selection.providerStorage,
      model: result.usage?.model ?? selection.resolvedModelId,
      usage: result.usage,
      disposition: result.disposition,
    );
  }
}

abstract interface class PdfDocumentTextSource {
  Future<List<SourcePageText>> extractAllPages(String filePath);
}

class LocalPdfDocumentTextSource implements PdfDocumentTextSource {
  @override
  Future<List<SourcePageText>> extractAllPages(String filePath) {
    return PdfTextExtractor.extractPages(
      filePath: filePath,
      includeEmptyPages: true,
    );
  }
}

class PdfAiMaterialService {
  PdfAiMaterialService(
    this._db,
    this._client, {
    PdfDocumentTextSource? textSource,
    Uuid? uuid,
    this._settings,
  }) : _textSource = textSource ?? LocalPdfDocumentTextSource(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PdfAiCompletionClient _client;
  final PdfDocumentTextSource _textSource;
  final Uuid _uuid;
  final AiSettingsStore? _settings;
  final Set<String> _inFlight = {};

  /// Conservative app-level budget below DeepSeek's current 1M-token context.
  /// This leaves room for instructions, thinking, and the largest output mode.
  static const singleRequestSafeApproximateTokens = 60000;
  static const singleRequestSafeCharacters =
      singleRequestSafeApproximateTokens * 4;
  static const chunkCharacters = 60000;
  static const chunkDigestMaxOutputTokens = 8192;
  static const maxReductionLevels = 8;

  Stream<List<PdfAiMaterial>> watchForMaterial(String materialId) {
    return _db.watchPdfAiMaterials(materialId);
  }

  Future<List<PdfAiMaterial>> history({
    required String materialId,
    required PdfAiMaterialType type,
  }) {
    return _db.listPdfAiMaterials(
      materialId: materialId,
      type: type.storageValue,
    );
  }

  Future<PreparedPdfDocument> prepareDocument({
    required String title,
    required String filePath,
  }) async {
    final pages = isTextDocumentPath(filePath)
        ? await _pagesFromTextFile(filePath)
        : await _textSource.extractAllPages(filePath);
    if (pages.isEmpty) {
      throw StateError('The document has no pages that can be processed.');
    }
    final document = PdfDocumentRepresentation.build(
      title: title,
      pages: pages,
    );
    if (document.extractedCharacterCount == 0) {
      throw StateError(
        isTextDocumentPath(filePath)
            ? 'This text document is empty.'
            : 'This PDF has no extractable text. OCR is not available yet.',
      );
    }
    return document;
  }

  Future<List<SourcePageText>> _pagesFromTextFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('File is missing on this device.');
    }
    final text = await file.readAsString();
    return [SourcePageText(pageNumber: 1, text: text)];
  }

  Future<String> sourceFingerprint({
    required String title,
    required String filePath,
  }) async {
    return (await prepareDocument(
      title: title,
      filePath: filePath,
    )).sourceFingerprint;
  }

  /// Generates all requests first and inserts one immutable version only after
  /// the complete workflow succeeds. Partial output is not saved.
  Future<PdfAiMaterial> generate({
    required String materialId,
    required String title,
    required String filePath,
    required PdfAiMaterialType type,
    required AiExecutionSelection selection,
    String? customInstruction,
    String? storedInstruction,
    String? reformatSource,
    String? reuseSourceFingerprint,
  }) async {
    final result = await generateTracked(
      materialId: materialId,
      title: title,
      filePath: filePath,
      type: type,
      selection: selection,
      customInstruction: customInstruction,
      storedInstruction: storedInstruction,
      reformatSource: reformatSource,
      reuseSourceFingerprint: reuseSourceFingerprint,
    );
    final saved = result.saved;
    if (saved != null) return saved;
    throw PdfAiPartialResultException(
      markdown: result.partialMarkdown ?? '',
      disposition: result.disposition,
    );
  }

  /// Same workflow as [generate], with progress, checkpoints, and partials.
  Future<PdfAiGenerationResult> generateTracked({
    required String materialId,
    required String title,
    required String filePath,
    required PdfAiMaterialType type,
    required AiExecutionSelection selection,
    String? customInstruction,
    String? storedInstruction,
    String? reformatSource,
    String? reuseSourceFingerprint,
    PdfGenerationCheckpoint? resume,
    String? continueAfter,
    Future<void> Function(PdfGenerationUpdate update)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final operationKey = '$materialId:${type.storageValue}';
    if (!_inFlight.add(operationKey)) {
      throw StateError('${type.shortName} is already being generated.');
    }
    try {
      return await _generateTracked(
        materialId: materialId,
        title: title,
        filePath: filePath,
        type: type,
        selection: selection,
        customInstruction: customInstruction,
        storedInstruction: storedInstruction,
        reformatSource: reformatSource,
        reuseSourceFingerprint: reuseSourceFingerprint,
        resume: resume,
        continueAfter: continueAfter,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } finally {
      _inFlight.remove(operationKey);
    }
  }

  Future<PdfAiGenerationResult> _generateTracked({
    required String materialId,
    required String title,
    required String filePath,
    required PdfAiMaterialType type,
    required AiExecutionSelection selection,
    String? customInstruction,
    String? storedInstruction,
    String? reformatSource,
    String? reuseSourceFingerprint,
    PdfGenerationCheckpoint? resume,
    String? continueAfter,
    Future<void> Function(PdfGenerationUpdate update)? onProgress,
    bool Function()? isCancelled,
  }) async {
    Future<void> report(PdfGenerationUpdate update) async {
      await onProgress?.call(update);
    }

    void ensureRunning() {
      if (isCancelled?.call() == true) throw const PdfGenerationCancelled();
    }

    final currentMarkdown = reformatSource?.trim();
    final reformatOnly = currentMarkdown != null && currentMarkdown.isNotEmpty;
    final stopwatch = Stopwatch()..start();
    final calls = <PdfAiCompletion>[];
    final userStyle = await _settings?.styleForSend(
      provider: selection.provider,
    );
    final continuation = continueAfter?.trim();

    if (reformatOnly) {
      ensureRunning();
      report(
        const PdfGenerationUpdate(
          phase: PdfGenerationPhase.generatingFinalOutput,
        ),
      );
      final fingerprint =
          reuseSourceFingerprint ??
          (await prepareDocument(
            title: title,
            filePath: filePath,
          )).sourceFingerprint;
      final finalCompletion = await _complete(
        messages: continuation == null
            ? PdfAiPromptBuilder.reformatMessages(
                type: type,
                currentMarkdown: currentMarkdown,
                extraInstruction: customInstruction,
                userStyle: userStyle,
              )
            : PdfAiPromptBuilder.continuationMessages(
                type: type,
                partialMarkdown: continuation,
                sourceExcerpt: currentMarkdown,
                customInstruction: customInstruction,
                userStyle: userStyle,
              ),
        maxOutputTokens: type.maxOutputTokens,
        selection: selection,
        onPartialText: (text) => report(
          PdfGenerationUpdate(
            phase: PdfGenerationPhase.generatingFinalOutput,
            partialText: text,
          ),
        ),
      );
      calls.add(finalCompletion);
      return _finishGeneration(
        materialId: materialId,
        type: type,
        completion: finalCompletion,
        calls: calls,
        stopwatch: stopwatch,
        sourceFingerprint: fingerprint,
        customInstruction: storedInstruction ?? customInstruction,
        appendToLessonSummary: false,
        continueAfter: continuation,
        checkpoint: null,
        report: report,
      );
    }

    ensureRunning();
    report(
      const PdfGenerationUpdate(phase: PdfGenerationPhase.extractingDocument),
    );
    final document = await prepareDocument(title: title, filePath: filePath);
    final fingerprint = document.sourceFingerprint;
    final checkpoint = resume?.sourceFingerprint == fingerprint ? resume : null;
    late final PdfAiCompletion finalCompletion;
    PdfGenerationCheckpoint? latest = checkpoint;
    if (document.stableDocument.length <= singleRequestSafeCharacters) {
      ensureRunning();
      report(
        const PdfGenerationUpdate(
          phase: PdfGenerationPhase.generatingFinalOutput,
        ),
      );
      finalCompletion = await _complete(
        messages: continuation == null
            ? PdfAiPromptBuilder.messages(
                stableDocument: document.stableDocument,
                type: type,
                customInstruction: customInstruction,
                userStyle: userStyle,
              )
            : PdfAiPromptBuilder.continuationMessages(
                type: type,
                partialMarkdown: continuation,
                sourceExcerpt: document.stableDocument,
                customInstruction: customInstruction,
                userStyle: userStyle,
              ),
        maxOutputTokens: type.maxOutputTokens,
        selection: selection,
        onPartialText: (text) => report(
          PdfGenerationUpdate(
            phase: PdfGenerationPhase.generatingFinalOutput,
            partialText: text,
          ),
        ),
      );
      calls.add(finalCompletion);
    } else {
      var digests = <String>[...?checkpoint?.digests];
      var reductionLevel = checkpoint?.reductionLevel ?? 0;
      var completedLevel =
          checkpoint?.completedLevelDigests ?? const <String>[];
      var readyForFinal = checkpoint?.readyForFinal ?? false;
      if (!readyForFinal) {
        final initialChunks = document.chunks(maxCharacters: chunkCharacters);
        if (reductionLevel == 0) {
          digests = await _digestChunks(
            chunks: initialChunks,
            calls: calls,
            selection: selection,
            existing: digests,
            isCancelled: ensureRunning,
            onCheckpoint: (done, count) async {
              latest = PdfGenerationCheckpoint(
                sourceFingerprint: fingerprint,
                digests: done,
                chunkCount: count,
              );
              await report(
                PdfGenerationUpdate(
                  phase: PdfGenerationPhase.digestingChunks,
                  current: done.length,
                  total: count,
                  checkpoint: latest,
                ),
              );
            },
          );
          completedLevel = digests;
        }
        var synthesis = PdfAiPromptBuilder.synthesisDocument(
          title: document.title,
          chunkDigests: reductionLevel == 0 ? digests : completedLevel,
        );
        while (synthesis.length > singleRequestSafeCharacters) {
          if (reductionLevel >= maxReductionLevels) {
            throw StateError(
              'The PDF remains too large after hierarchical reduction.',
            );
          }
          if (reductionLevel == (checkpoint?.reductionLevel ?? 0) &&
              reductionLevel > 0) {
            synthesis = PdfAiPromptBuilder.synthesisDocument(
              title: document.title,
              chunkDigests: completedLevel,
            );
          }
          report(
            const PdfGenerationUpdate(phase: PdfGenerationPhase.synthesizing),
          );
          reductionLevel++;
          final levelChunks = _splitDeterministically(
            synthesis,
            chunkCharacters,
          );
          final levelExisting = reductionLevel == checkpoint?.reductionLevel
              ? (checkpoint?.digests ?? const <String>[])
              : const <String>[];
          digests = await _digestChunks(
            chunks: levelChunks,
            calls: calls,
            selection: selection,
            existing: levelExisting,
            isCancelled: ensureRunning,
            onCheckpoint: (done, count) async {
              latest = PdfGenerationCheckpoint(
                sourceFingerprint: fingerprint,
                reductionLevel: reductionLevel,
                digests: done,
                completedLevelDigests: completedLevel,
                chunkCount: count,
              );
              await report(
                PdfGenerationUpdate(
                  phase: PdfGenerationPhase.digestingChunks,
                  current: done.length,
                  total: count,
                  checkpoint: latest,
                ),
              );
            },
          );
          completedLevel = digests;
          synthesis = PdfAiPromptBuilder.synthesisDocument(
            title: document.title,
            chunkDigests: digests,
          );
        }
        readyForFinal = true;
        latest = PdfGenerationCheckpoint(
          sourceFingerprint: fingerprint,
          reductionLevel: reductionLevel,
          digests: digests,
          completedLevelDigests: completedLevel,
          chunkCount: digests.length,
          readyForFinal: true,
        );
        report(
          PdfGenerationUpdate(
            phase: PdfGenerationPhase.synthesizing,
            checkpoint: latest,
          ),
        );
        ensureRunning();
        report(
          const PdfGenerationUpdate(
            phase: PdfGenerationPhase.generatingFinalOutput,
          ),
        );
        finalCompletion = await _complete(
          messages: continuation == null
              ? PdfAiPromptBuilder.messages(
                  stableDocument: synthesis,
                  type: type,
                  customInstruction: customInstruction,
                  userStyle: userStyle,
                )
              : PdfAiPromptBuilder.continuationMessages(
                  type: type,
                  partialMarkdown: continuation,
                  sourceExcerpt: synthesis,
                  customInstruction: customInstruction,
                  userStyle: userStyle,
                ),
          maxOutputTokens: type.maxOutputTokens,
          selection: selection,
          onPartialText: (text) => report(
            PdfGenerationUpdate(
              phase: PdfGenerationPhase.generatingFinalOutput,
              partialText: text,
              checkpoint: latest,
            ),
          ),
        );
        calls.add(finalCompletion);
      } else {
        final synthesis = PdfAiPromptBuilder.synthesisDocument(
          title: document.title,
          chunkDigests: checkpoint?.digests ?? const [],
        );
        ensureRunning();
        report(
          PdfGenerationUpdate(
            phase: PdfGenerationPhase.generatingFinalOutput,
            checkpoint: latest,
          ),
        );
        finalCompletion = await _complete(
          messages: continuation == null
              ? PdfAiPromptBuilder.messages(
                  stableDocument: synthesis,
                  type: type,
                  customInstruction: customInstruction,
                  userStyle: userStyle,
                )
              : PdfAiPromptBuilder.continuationMessages(
                  type: type,
                  partialMarkdown: continuation,
                  sourceExcerpt: synthesis,
                  customInstruction: customInstruction,
                  userStyle: userStyle,
                ),
          maxOutputTokens: type.maxOutputTokens,
          selection: selection,
          onPartialText: (text) => report(
            PdfGenerationUpdate(
              phase: PdfGenerationPhase.generatingFinalOutput,
              partialText: text,
              checkpoint: latest,
            ),
          ),
        );
        calls.add(finalCompletion);
      }
    }
    return _finishGeneration(
      materialId: materialId,
      type: type,
      completion: finalCompletion,
      calls: calls,
      stopwatch: stopwatch,
      sourceFingerprint: fingerprint,
      customInstruction: storedInstruction ?? customInstruction,
      continueAfter: continuation,
      checkpoint: latest,
      report: report,
    );
  }

  Future<PdfAiCompletion> _complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) {
    return _client.complete(
      messages: messages,
      maxOutputTokens: maxOutputTokens,
      selection: selection,
      onPartialText: selection.provider == AiProviderId.newApi
          ? onPartialText
          : null,
    );
  }

  Future<PdfAiGenerationResult> _finishGeneration({
    required String materialId,
    required PdfAiMaterialType type,
    required PdfAiCompletion completion,
    required List<PdfAiCompletion> calls,
    required Stopwatch stopwatch,
    required String sourceFingerprint,
    required String? customInstruction,
    required Future<void> Function(PdfGenerationUpdate update) report,
    String? continueAfter,
    PdfGenerationCheckpoint? checkpoint,
    bool appendToLessonSummary = true,
  }) async {
    if (completion.isPartial) {
      stopwatch.stop();
      return PdfAiGenerationResult(
        partialMarkdown: completion.markdown,
        disposition: completion.disposition,
        checkpoint: checkpoint,
      );
    }
    var markdown = completion.markdown.trim();
    if (continueAfter != null) {
      final merged = PartialTextMerge.merge(continueAfter, markdown);
      if (!merged.isSafe) {
        stopwatch.stop();
        return PdfAiGenerationResult(
          partialMarkdown: merged.text,
          disposition: AiCompletionDisposition.complete,
          checkpoint: checkpoint,
          mergeNeedsReview: true,
          reviewMessage: merged.message,
        );
      }
      markdown = merged.text.trim();
    }
    await report(const PdfGenerationUpdate(phase: PdfGenerationPhase.saving));
    stopwatch.stop();
    final saved = await _saveVersion(
      materialId: materialId,
      type: type,
      completedMarkdown: markdown,
      finalCompletion: completion,
      calls: calls,
      durationMs: stopwatch.elapsedMilliseconds,
      sourceFingerprint: sourceFingerprint,
      customInstruction: customInstruction,
      appendToLessonSummary: appendToLessonSummary,
    );
    return PdfAiGenerationResult(saved: saved);
  }

  Future<PdfAiMaterial> _saveVersion({
    required String materialId,
    required PdfAiMaterialType type,
    required String completedMarkdown,
    required PdfAiCompletion finalCompletion,
    required List<PdfAiCompletion> calls,
    required int durationMs,
    required String sourceFingerprint,
    String? customInstruction,
    bool appendToLessonSummary = true,
  }) async {
    if (completedMarkdown.isEmpty) {
      throw StateError('The AI returned an empty study material.');
    }
    final usage = AiTokenUsage.merge([
      for (final call in calls) call.usage,
    ])?.copyWith(durationMs: durationMs);
    final now = DateTime.now();
    final saved = await _db.insertPdfAiMaterialVersion(
      materialId: materialId,
      type: type.storageValue,
      builder: (version) => PdfAiMaterialsCompanion.insert(
        id: _uuid.v4(),
        materialId: materialId,
        type: type.storageValue,
        content: completedMarkdown,
        version: version,
        generatedAt: now,
        provider: Value(finalCompletion.provider),
        model: Value(finalCompletion.model),
        promptTokens: Value(usage?.promptTokens),
        completionTokens: Value(usage?.completionTokens),
        totalTokens: Value(usage?.totalTokens),
        cacheHitTokens: Value(usage?.cacheHitTokens),
        cacheMissTokens: Value(usage?.cacheMissTokens),
        requestDurationMs: Value(usage?.durationMs ?? durationMs),
        sourceFingerprint: sourceFingerprint,
        customInstruction: Value(_nullableTrim(customInstruction)),
      ),
    );
    if (appendToLessonSummary) await _appendToLessonSummary(saved);
    return saved;
  }

  Future<void> _appendToLessonSummary(PdfAiMaterial saved) async {
    if (saved.type != PdfAiMaterialType.summary.storageValue) return;
    await LessonSummaryRepository(
      _db,
    ).appendAiSummary(materialId: saved.materialId, markdown: saved.content);
  }

  Future<List<String>> _digestChunks({
    required List<String> chunks,
    required List<PdfAiCompletion> calls,
    required AiExecutionSelection selection,
    List<String> existing = const [],
    required void Function() isCancelled,
    Future<void> Function(List<String> digests, int chunkCount)? onCheckpoint,
  }) async {
    final digests = [...existing];
    final start = digests.length.clamp(0, chunks.length);
    for (var i = start; i < chunks.length; i++) {
      isCancelled();
      final completion = await _client.complete(
        messages: PdfAiPromptBuilder.chunkDigestMessages(
          documentChunk: chunks[i],
          chunkNumber: i + 1,
          chunkCount: chunks.length,
        ),
        maxOutputTokens: chunkDigestMaxOutputTokens,
        selection: selection,
      );
      calls.add(completion);
      if (completion.isPartial) {
        await onCheckpoint?.call(digests, chunks.length);
        throw StateError(
          completion.disposition == AiCompletionDisposition.partialTimeout
              ? 'The chunk request timed out. No partial response was received.'
              : 'The chunk request was interrupted. Completed sections were saved.',
        );
      }
      final digest = completion.markdown.trim();
      if (digest.isEmpty) {
        throw StateError('The AI returned an empty chunk digest.');
      }
      digests.add(digest);
      await onCheckpoint?.call(digests, chunks.length);
    }
    return digests;
  }

  /// Saves text the user explicitly accepted, including a partial result.
  Future<PdfAiMaterial> saveProvidedMarkdown({
    required String materialId,
    required PdfAiMaterialType type,
    required String content,
    required String provider,
    required String model,
    String? sourceFingerprint,
    String? customInstruction,
  }) async {
    final markdown = content.trim();
    if (markdown.isEmpty) throw ArgumentError.value(content, 'content');
    final saved = await _db.insertPdfAiMaterialVersion(
      materialId: materialId,
      type: type.storageValue,
      builder: (version) => PdfAiMaterialsCompanion.insert(
        id: _uuid.v4(),
        materialId: materialId,
        type: type.storageValue,
        content: markdown,
        version: version,
        generatedAt: DateTime.now(),
        provider: Value(provider),
        model: Value(model),
        sourceFingerprint:
            sourceFingerprint ??
            sha256.convert(utf8.encode(markdown)).toString(),
        customInstruction: Value(_nullableTrim(customInstruction)),
      ),
    );
    await _appendToLessonSummary(saved);
    return saved;
  }

  Future<PdfAiMaterial> editVersion({
    required PdfAiMaterial original,
    required String content,
  }) => _db.editPdfAiMaterial(
    original: original,
    id: _uuid.v4(),
    content: content,
  );

  /// Overwrites one version in place (no new version row).
  Future<PdfAiMaterial> overwriteVersion({
    required PdfAiMaterial original,
    required String content,
  }) => _db.updatePdfAiMaterialContent(id: original.id, content: content);

  Future<PdfAiMaterial> importManual({
    required String materialId,
    required PdfAiMaterialType type,
    required String content,
    String? sourceFingerprint,
  }) async {
    final markdown = content.trim();
    if (markdown.isEmpty) {
      throw ArgumentError.value(content, 'content');
    }
    final saved = await _db.insertPdfAiMaterialVersion(
      materialId: materialId,
      type: type.storageValue,
      builder: (version) => PdfAiMaterialsCompanion.insert(
        id: _uuid.v4(),
        materialId: materialId,
        type: type.storageValue,
        content: markdown,
        version: version,
        generatedAt: DateTime.now(),
        provider: const Value('manual'),
        model: const Value('json_import'),
        sourceFingerprint:
            sourceFingerprint ??
            sha256.convert(utf8.encode(markdown)).toString(),
        customInstruction: const Value('Manual JSON'),
      ),
    );
    await _appendToLessonSummary(saved);
    return saved;
  }

  Future<void> deleteVersion(String id) => _db.deletePdfAiMaterial(id);

  static List<String> _splitDeterministically(String text, int maxCharacters) {
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + maxCharacters).clamp(0, text.length);
      if (end > start && end < text.length) {
        final previous = text.codeUnitAt(end - 1);
        final next = text.codeUnitAt(end);
        if (previous >= 0xd800 &&
            previous <= 0xdbff &&
            next >= 0xdc00 &&
            next <= 0xdfff) {
          end--;
        }
      }
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
