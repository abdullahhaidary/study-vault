import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/study_vault_paths.dart';
import '../data/book_repository.dart';
import '../domain/book_chapter_detector.dart';
import '../domain/book_text_index.dart';

/// Book files live under the synced materials folder:
/// `study_vault_files/books/{bookId}/{storedFileName}`.
abstract final class BookStorage {
  static String relativePath(String bookId, String storedFileName) =>
      'books/$bookId/$storedFileName';

  static Future<String> absolutePath(ReferenceBook book) async {
    final root = await StudyVaultPaths.materialsDirectory();
    return p.join(root.path, 'books', book.id, book.storedFileName);
  }

  static Future<void> deleteFiles(String bookId) async {
    final root = await StudyVaultPaths.materialsDirectory();
    final dir = Directory(p.join(root.path, 'books', bookId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Reads a PDF's page count, bookmarks and page text.
abstract interface class BookPdfReader {
  Future<int> pageCount(String filePath);
  Future<List<OutlineEntry>> outline(String filePath);

  /// Calls [onBatch] with page text in order, [batchSize] pages at a time.
  Future<void> readPages(
    String filePath, {
    required int fromPage,
    required int batchSize,
    required Future<bool> Function(List<BookPage> batch) onBatch,
  });
}

class PdfrxBookReader implements BookPdfReader {
  @override
  Future<int> pageCount(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<List<OutlineEntry>> outline(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final result = <OutlineEntry>[];
      void walk(List<PdfOutlineNode> nodes, int level) {
        for (final node in nodes) {
          final page = node.dest?.pageNumber;
          if (page != null) result.add(OutlineEntry(node.title, level, page));
          walk(node.children, level + 1);
        }
      }

      walk(await doc.loadOutline(), 0);
      return result;
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<void> readPages(
    String filePath, {
    required int fromPage,
    required int batchSize,
    required Future<bool> Function(List<BookPage> batch) onBatch,
  }) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      var batch = <BookPage>[];
      for (final page in doc.pages.where((pg) => pg.pageNumber >= fromPage)) {
        final text = (await page.loadText())?.fullText.trim() ?? '';
        batch.add(BookPage(page.pageNumber, text));
        if (batch.length >= batchSize) {
          if (!await onBatch(batch)) return;
          batch = [];
        }
      }
      if (batch.isNotEmpty) await onBatch(batch);
    } finally {
      await doc.dispose();
    }
  }
}

typedef BookProgress = void Function(int done, int total);

class BookImportService {
  BookImportService(
    this._repository, {
    BookPdfReader? reader,
    Future<Directory> Function()? filesRoot,
  }) : _reader = reader ?? PdfrxBookReader(),
       _filesRoot = filesRoot ?? StudyVaultPaths.materialsDirectory;

  final BookRepository _repository;
  final BookPdfReader _reader;
  final Future<Directory> Function() _filesRoot;

  static const batchSize = 40;

  /// Copies the PDF into storage, builds chapters from its bookmarks (or
  /// page blocks until text headings are found during indexing) and creates
  /// the book. Indexing runs separately via [indexBook].
  Future<ReferenceBook> importBook({
    required String sourcePath,
    required String title,
    String? author,
    List<String> subjectIds = const [],
  }) async {
    final id = _repository.newId();
    final originalName = p.basename(sourcePath);
    final stored = '${_repository.newId()}.pdf';
    final root = await _filesRoot();
    final target = File(
      p.join(root.path, BookStorage.relativePath(id, stored)),
    );
    await target.parent.create(recursive: true);
    await File(sourcePath).copy(target.path);
    try {
      final pageCount = await _reader.pageCount(target.path);
      if (pageCount < 1) throw StateError('The PDF has no pages.');
      final outline = await _reader.outline(target.path);
      await _repository.createBook(
        id: id,
        title: title,
        author: author,
        originalFileName: originalName,
        storedFileName: stored,
        pageCount: pageCount,
        chapters: BookChapterDetector.detect(
          pageCount: pageCount,
          outline: outline,
          pageText: const {},
        ),
        subjectIds: subjectIds,
      );
    } catch (_) {
      await target.parent.delete(recursive: true);
      rethrow;
    }
    return (await _repository.book(id))!;
  }

  /// Extracts page text into the device-local index. Resumes where an
  /// interrupted run stopped.
  Future<void> indexBook(
    ReferenceBook book, {
    String? filePath,
    BookProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final path = filePath ?? await BookStorage.absolutePath(book);
    if (!await File(path).exists()) {
      throw StateError(
        'The book file is not on this device yet. Sync to download it.',
      );
    }
    var state = await _repository.localState(book.id);
    if (state.storedFileName != book.storedFileName ||
        state.pageCount != book.pageCount) {
      await _repository.startIndex(book);
      state = await _repository.localState(book.id);
    }
    var done = state.indexedPages;
    onProgress?.call(done, book.pageCount);
    if (done >= book.pageCount) return;
    await _reader.readPages(
      path,
      fromPage: done + 1,
      batchSize: batchSize,
      onBatch: (batch) async {
        await _repository.savePages(book.id, batch);
        done += batch.length;
        onProgress?.call(done, book.pageCount);
        return !(isCancelled?.call() ?? false);
      },
    );
  }

  /// Re-runs chapter detection (keeps the book, replaces chapters).
  Future<void> redetectChapters(ReferenceBook book) async {
    final path = await BookStorage.absolutePath(book);
    final outline = await _reader.outline(path);
    final pages = await _repository.pages(book.id);
    await _repository.replaceChapters(
      book.id,
      BookChapterDetector.detect(
        pageCount: book.pageCount,
        outline: outline,
        pageText: {for (final pg in pages) pg.page: pg.text},
      ),
    );
  }
}
