import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_pdf_document.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import 'book_import_service.dart';

abstract interface class BookPdfSource {
  /// Null pages means an explicitly chosen whole-book attachment.
  Future<AiPdfDocument> prepare(
    ReferenceBook book, {
    List<int>? pages,
    required int maxPages,
  });
}

class LocalBookPdfSource implements BookPdfSource {
  LocalBookPdfSource({Future<String> Function(ReferenceBook)? resolvePath})
    : _resolvePath = resolvePath ?? BookStorage.absolutePath;
  final Future<String> Function(ReferenceBook) _resolvePath;
  @override
  Future<AiPdfDocument> prepare(
    ReferenceBook book, {
    List<int>? pages,
    required int maxPages,
  }) async {
    final selected =
        pages == null
              ? [for (var p = 1; p <= book.pageCount; p++) p]
              : [...pages]
          ..sort();
    if (selected.isEmpty ||
        selected.length > maxPages ||
        selected.first < 1 ||
        selected.last > book.pageCount) {
      throw AiMalformedOutputException(
        'Choose between 1 and $maxPages pages within this book. For a larger book, select a chapter or use extracted text.',
      );
    }
    final path = await _resolvePath(book);
    final file = File(path);
    if (!await file.exists()) {
      throw const AiMalformedOutputException(
        'The book PDF is not available on this device.',
      );
    }
    if (pages == null && await file.length() > AiPdfDocument.maxBytes) {
      throw const AiMalformedOutputException(
        'The book PDF exceeds 20 MiB. Choose a chapter/page range or use extracted text.',
      );
    }
    final original = await PdfDocument.openFile(path);
    try {
      if (original.pages.length != book.pageCount) {
        throw const AiMalformedOutputException(
          'The PDF page count changed. Reimport this book before sending it.',
        );
      }
      if (pages == null) {
        if (original.isEncrypted) {
          throw const AiMalformedOutputException(
            'Encrypted PDFs cannot be attached. Use extracted text or import an unencrypted PDF.',
          );
        }
        return AiPdfDocument(
          bytes: await file.readAsBytes(),
          fileName: book.originalFileName,
          sourcePages: selected,
        );
      }
      if (selected.last > original.pages.length) {
        throw const AiMalformedOutputException(
          'The book file changed. Open and reindex it before sending pages.',
        );
      }
      final excerpt = await PdfDocument.createNew(
        sourceName: 'book-excerpt.pdf',
      );
      try {
        excerpt.pages = [for (final page in selected) original.pages[page - 1]];
        return AiPdfDocument(
          bytes: await excerpt.encodePdf(),
          fileName: 'book-pages-${selected.first}-${selected.last}.pdf',
          sourcePages: selected,
        );
      } finally {
        await excerpt.dispose();
      }
    } finally {
      await original.dispose();
    }
  }
}
