import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/services/deepseek_ai_service.dart';
import '../../ai_assistant/services/gemini_ai_service.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/services/pdf_text_extractor.dart';
import '../domain/pdf_ai_material_models.dart';

class PdfAiCompletion {
  const PdfAiCompletion({
    required this.markdown,
    required this.provider,
    required this.model,
    this.usage,
  });

  final String markdown;
  final String provider;
  final String model;
  final AiTokenUsage? usage;
}

abstract interface class PdfAiCompletionClient {
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  });
}

/// Routes document completions to Gemini or DeepSeek from [selection].
class RoutingPdfAiCompletionClient implements PdfAiCompletionClient {
  RoutingPdfAiCompletionClient({
    required GeminiAiService gemini,
    required DeepSeekAiService deepSeek,
  }) : _gemini = gemini,
       _deepSeek = deepSeek;

  final GeminiAiService _gemini;
  final DeepSeekAiService _deepSeek;

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
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
    };
    return PdfAiCompletion(
      markdown: result.markdown,
      provider: selection.providerStorage,
      model: result.usage?.model ?? selection.resolvedModelId,
      usage: result.usage,
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
  }) : _textSource = textSource ?? LocalPdfDocumentTextSource(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PdfAiCompletionClient _client;
  final PdfDocumentTextSource _textSource;
  final Uuid _uuid;
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
    final pages = await _textSource.extractAllPages(filePath);
    if (pages.isEmpty) {
      throw StateError('The PDF has no pages that can be processed.');
    }
    final document = PdfDocumentRepresentation.build(
      title: title,
      pages: pages,
    );
    if (document.extractedCharacterCount == 0) {
      throw StateError(
        'This PDF has no extractable text. OCR is not available yet.',
      );
    }
    return document;
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
  /// the complete workflow succeeds.
  Future<PdfAiMaterial> generate({
    required String materialId,
    required String title,
    required String filePath,
    required PdfAiMaterialType type,
    required AiExecutionSelection selection,
    String? customInstruction,
  }) async {
    final operationKey = '$materialId:${type.storageValue}';
    if (!_inFlight.add(operationKey)) {
      throw StateError('${type.shortName} is already being generated.');
    }
    try {
      return await _generateOnce(
        materialId: materialId,
        title: title,
        filePath: filePath,
        type: type,
        selection: selection,
        customInstruction: customInstruction,
      );
    } finally {
      _inFlight.remove(operationKey);
    }
  }

  Future<PdfAiMaterial> _generateOnce({
    required String materialId,
    required String title,
    required String filePath,
    required PdfAiMaterialType type,
    required AiExecutionSelection selection,
    String? customInstruction,
  }) async {
    final document = await prepareDocument(title: title, filePath: filePath);
    final stopwatch = Stopwatch()..start();
    final calls = <PdfAiCompletion>[];

    late final PdfAiCompletion finalCompletion;
    if (document.stableDocument.length <= singleRequestSafeCharacters) {
      finalCompletion = await _client.complete(
        messages: PdfAiPromptBuilder.messages(
          stableDocument: document.stableDocument,
          type: type,
          customInstruction: customInstruction,
        ),
        maxOutputTokens: type.maxOutputTokens,
        selection: selection,
      );
      calls.add(finalCompletion);
    } else {
      var digests = await _digestChunks(
        chunks: document.chunks(maxCharacters: chunkCharacters),
        calls: calls,
        selection: selection,
      );
      var synthesis = PdfAiPromptBuilder.synthesisDocument(
        title: document.title,
        chunkDigests: digests,
      );
      var reductionLevel = 0;
      while (synthesis.length > singleRequestSafeCharacters) {
        if (reductionLevel >= maxReductionLevels) {
          throw StateError(
            'The PDF remains too large after hierarchical reduction.',
          );
        }
        digests = await _digestChunks(
          chunks: _splitDeterministically(synthesis, chunkCharacters),
          calls: calls,
          selection: selection,
        );
        synthesis = PdfAiPromptBuilder.synthesisDocument(
          title: document.title,
          chunkDigests: digests,
        );
        reductionLevel++;
      }
      finalCompletion = await _client.complete(
        messages: PdfAiPromptBuilder.messages(
          stableDocument: synthesis,
          type: type,
          customInstruction: customInstruction,
        ),
        maxOutputTokens: type.maxOutputTokens,
        selection: selection,
      );
      calls.add(finalCompletion);
    }
    stopwatch.stop();
    final completedMarkdown = finalCompletion.markdown.trim();
    if (completedMarkdown.isEmpty) {
      throw StateError('The AI returned an empty study material.');
    }

    final usage = AiTokenUsage.merge([
      for (final call in calls) call.usage,
    ])?.copyWith(durationMs: stopwatch.elapsedMilliseconds);
    final now = DateTime.now();
    return _db.insertPdfAiMaterialVersion(
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
        requestDurationMs: Value(
          usage?.durationMs ?? stopwatch.elapsedMilliseconds,
        ),
        sourceFingerprint: document.sourceFingerprint,
        customInstruction: Value(_nullableTrim(customInstruction)),
      ),
    );
  }

  Future<List<String>> _digestChunks({
    required List<String> chunks,
    required List<PdfAiCompletion> calls,
    required AiExecutionSelection selection,
  }) async {
    final digests = <String>[];
    for (var i = 0; i < chunks.length; i++) {
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
      final digest = completion.markdown.trim();
      if (digest.isEmpty) {
        throw StateError('The AI returned an empty chunk digest.');
      }
      digests.add(digest);
    }
    return digests;
  }

  Future<PdfAiMaterial> editVersion({
    required PdfAiMaterial original,
    required String content,
  }) => _db.editPdfAiMaterial(
    original: original,
    id: _uuid.v4(),
    content: content,
  );

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
