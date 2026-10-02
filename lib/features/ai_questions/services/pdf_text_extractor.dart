import 'package:pdfrx/pdfrx.dart';

import '../domain/question_source.dart';

/// Extracts plain text from PDF pages via pdfrx.
abstract final class PdfTextExtractor {
  /// Loads text for [pageNumbers] (1-based). Empty set → all pages.
  static Future<List<SourcePageText>> extractPages({
    required String filePath,
    Set<int>? pageNumbers,
  }) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final results = <SourcePageText>[];
      for (final page in doc.pages) {
        if (pageNumbers != null &&
            pageNumbers.isNotEmpty &&
            !pageNumbers.contains(page.pageNumber)) {
          continue;
        }
        final raw = await page.loadText();
        final text = raw?.fullText.trim() ?? '';
        if (text.isEmpty) continue;
        results.add(SourcePageText(pageNumber: page.pageNumber, text: text));
      }
      return results;
    } finally {
      await doc.dispose();
    }
  }

  static Future<int> pageCount(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }
}
