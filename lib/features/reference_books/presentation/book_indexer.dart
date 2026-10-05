import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../data/book_providers.dart';
import '../services/book_import_service.dart';

/// Status of a background job for one book.
class BookJob {
  const BookJob({
    required this.label,
    this.done = 0,
    this.total = 0,
    this.error,
  });

  final String label;
  final int done;
  final int total;
  final String? error;

  bool get running => error == null;
  double? get progress => total == 0 ? null : done / total;
}

/// Runs indexing and smart-search builds in the background so they keep
/// going while the user navigates.
class BookIndexer extends StateNotifier<Map<String, BookJob>> {
  BookIndexer(this._ref) : super(const {});

  final Ref _ref;

  bool isRunning(String bookId) => state[bookId]?.running ?? false;

  void _set(String bookId, BookJob? job) {
    final next = Map.of(state);
    if (job == null) {
      next.remove(bookId);
    } else {
      next[bookId] = job;
    }
    state = next;
  }

  /// Indexes the book if this device has not finished it yet.
  Future<void> ensureIndexed(
    ReferenceBook book, {
    bool detectHeadings = false,
  }) async {
    if (isRunning(book.id)) return;
    final repository = _ref.read(bookRepositoryProvider);
    final local = await repository.localState(book.id);
    if (local.isIndexed(book)) return;
    if (!await File(await BookStorage.absolutePath(book)).exists()) return;
    _set(book.id, const BookJob(label: 'Indexing pages'));
    try {
      await _ref
          .read(bookImportServiceProvider)
          .indexBook(
            book,
            onProgress: (done, total) => _set(
              book.id,
              BookJob(label: 'Indexing pages', done: done, total: total),
            ),
          );
      _ref.read(bookSearchServiceProvider).invalidate(book.id);
      if (detectHeadings) {
        final chapters = await repository.chapters(book.id);
        final blocksOnly = chapters.every(
          (c) => RegExp(r'^Pages \d+–\d+$').hasMatch(c.title),
        );
        if (blocksOnly) {
          await _ref.read(bookImportServiceProvider).redetectChapters(book);
        }
      }
      _set(book.id, null);
    } on Object catch (e) {
      _set(
        book.id,
        BookJob(label: 'Indexing failed', error: aiErrorMessage(e)),
      );
    }
  }

  Future<void> buildSmartSearch(ReferenceBook book) async {
    if (isRunning(book.id)) return;
    _set(book.id, const BookJob(label: 'Building smart search'));
    try {
      await _ref
          .read(bookSearchServiceProvider)
          .buildVectors(
            book.id,
            onProgress: (done, total) => _set(
              book.id,
              BookJob(label: 'Building smart search', done: done, total: total),
            ),
          );
      _set(book.id, null);
    } on Object catch (e) {
      _set(
        book.id,
        BookJob(label: 'Smart search failed', error: aiErrorMessage(e)),
      );
    }
  }

  void dismiss(String bookId) => _set(bookId, null);
}

final bookIndexerProvider =
    StateNotifierProvider<BookIndexer, Map<String, BookJob>>(
      (ref) => BookIndexer(ref),
    );
