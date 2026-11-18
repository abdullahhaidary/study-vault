import 'dart:convert';
import 'dart:typed_data';
import 'ai_exceptions.dart';

/// Transient request data. PDF bytes and provider-side identifiers never enter
/// settings, synchronized records, or diagnostic logs.
class AiPdfDocument {
  AiPdfDocument({
    required this.bytes,
    required this.fileName,
    required List<int> sourcePages,
  }) : sourcePages = List.unmodifiable(sourcePages) {
    if (bytes.length < 5 ||
        ascii.decode(bytes.sublist(0, 5), allowInvalid: true) != '%PDF-') {
      throw const AiMalformedOutputException(
        'The attachment is not a valid PDF file.',
      );
    }
    if (bytes.length > maxBytes) {
      throw const AiMalformedOutputException(
        'The PDF attachment exceeds 20 MiB. Choose fewer pages or use extracted text.',
      );
    }
    if (sourcePages.isEmpty ||
        sourcePages.any((p) => p < 1) ||
        sourcePages.toSet().length != sourcePages.length) {
      throw const AiMalformedOutputException(
        'Choose valid, distinct book pages for the PDF attachment.',
      );
    }
  }
  static const maxBytes = 20 * 1024 * 1024;
  final Uint8List bytes;
  final String fileName;
  final List<int> sourcePages;
  late final String base64Data = base64Encode(bytes);
  String get pageMap =>
      'ATTACHED PDF PAGE MAP (use original book page numbers in citations):\n'
      '${[for (var i = 0; i < sourcePages.length; i++) 'Attached page ${i + 1} = book page ${sourcePages[i]}'].join('\n')}';

  void validatePageLimit(int limit) {
    if (sourcePages.length > limit) {
      throw AiMalformedOutputException(
        'This PDF contains ${sourcePages.length} pages; this endpoint is configured for at most $limit per request. Choose a chapter/page range or use extracted text.',
      );
    }
  }
}
