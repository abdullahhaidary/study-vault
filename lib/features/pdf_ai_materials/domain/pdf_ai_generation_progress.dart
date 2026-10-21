import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_models.dart';

enum PdfGenerationPhase {
  extractingDocument,
  digestingChunks,
  synthesizing,
  generatingFinalOutput,
  saving,
}

class PdfGenerationCheckpoint {
  const PdfGenerationCheckpoint({
    this.version = 1,
    required this.sourceFingerprint,
    this.reductionLevel = 0,
    this.digests = const [],
    this.completedLevelDigests = const [],
    this.chunkCount = 0,
    this.readyForFinal = false,
  });

  final int version;
  final String sourceFingerprint;
  final int reductionLevel;
  final List<String> digests;
  final List<String> completedLevelDigests;
  final int chunkCount;
  final bool readyForFinal;

  Map<String, Object?> toJson() => {
    'v': version,
    'sourceFingerprint': sourceFingerprint,
    'reductionLevel': reductionLevel,
    'digests': digests,
    'completedLevelDigests': completedLevelDigests,
    'chunkCount': chunkCount,
    'readyForFinal': readyForFinal,
  };

  factory PdfGenerationCheckpoint.fromJson(Map<String, Object?> json) {
    return PdfGenerationCheckpoint(
      version: json['v'] as int? ?? 1,
      sourceFingerprint: json['sourceFingerprint'] as String? ?? '',
      reductionLevel: json['reductionLevel'] as int? ?? 0,
      digests: [
        for (final item in json['digests'] as List<Object?>? ?? const [])
          if (item is String) item,
      ],
      completedLevelDigests: [
        for (final item
            in json['completedLevelDigests'] as List<Object?>? ?? const [])
          if (item is String) item,
      ],
      chunkCount: json['chunkCount'] as int? ?? 0,
      readyForFinal: json['readyForFinal'] == true,
    );
  }
}

class PdfGenerationUpdate {
  const PdfGenerationUpdate({
    required this.phase,
    this.current = 0,
    this.total = 0,
    this.partialText,
    this.checkpoint,
  });

  final PdfGenerationPhase phase;
  final int current;
  final int total;
  final String? partialText;
  final PdfGenerationCheckpoint? checkpoint;
}

class PdfAiGenerationResult {
  const PdfAiGenerationResult({
    this.saved,
    this.partialMarkdown,
    this.disposition = AiCompletionDisposition.complete,
    this.checkpoint,
    this.mergeNeedsReview = false,
    this.reviewMessage,
  });

  final PdfAiMaterial? saved;
  final String? partialMarkdown;
  final AiCompletionDisposition disposition;
  final PdfGenerationCheckpoint? checkpoint;
  final bool mergeNeedsReview;
  final String? reviewMessage;

  bool get isPartial =>
      mergeNeedsReview || disposition != AiCompletionDisposition.complete;
}

class PdfAiPartialResultException implements Exception {
  const PdfAiPartialResultException({
    required this.markdown,
    required this.disposition,
  });

  final String markdown;
  final AiCompletionDisposition disposition;

  @override
  String toString() => 'Partial AI output was not saved.';
}

class PdfGenerationCancelled implements Exception {
  const PdfGenerationCancelled();
}

/// Joins a cut-off answer with a later continuation request.
class PartialMergeOutcome {
  const PartialMergeOutcome.safe(this.text) : message = null, isSafe = true;

  const PartialMergeOutcome.unsafe(this.text, this.message) : isSafe = false;

  final String text;
  final String? message;
  final bool isSafe;
}

abstract final class PartialTextMerge {
  static const minimumOverlap = 40;

  static PartialMergeOutcome merge(String partial, String continuation) {
    final head = partial.trimRight();
    final extra = continuation.trim();
    if (head.isEmpty) {
      return const PartialMergeOutcome.unsafe('', 'There is no partial text.');
    }
    if (extra.isEmpty) {
      return PartialMergeOutcome.unsafe(head, 'The continuation was empty.');
    }
    final limit = head.length < extra.length ? head.length : extra.length;
    var overlap = 0;
    for (var size = limit; size >= minimumOverlap; size--) {
      if (head.substring(head.length - size) == extra.substring(0, size)) {
        overlap = size;
        break;
      }
    }
    if (overlap >= minimumOverlap) {
      return PartialMergeOutcome.safe(head + extra.substring(overlap));
    }
    final lastHeading = RegExp(
      r'^#{1,6} .+$',
      multiLine: true,
    ).allMatches(head).lastOrNull?.group(0);
    if (lastHeading != null && extra.startsWith(lastHeading)) {
      return PartialMergeOutcome.unsafe(
        '$head\n\n$extra',
        'The continuation repeats a heading, so it was not joined automatically.',
      );
    }
    if (head.endsWith('\n') ||
        extra.startsWith('#') ||
        extra.startsWith('\n')) {
      return PartialMergeOutcome.safe('$head\n\n${extra.trimLeft()}');
    }
    return PartialMergeOutcome.unsafe(
      '$head\n\n$extra',
      'The join point is ambiguous, so the partial result was not saved.',
    );
  }
}
