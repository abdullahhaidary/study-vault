import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/book_chapter_detector.dart';
import '../domain/book_text_index.dart';
import '../domain/reading_plan.dart';

/// Device-local index state for one book.
class BookLocalState {
  const BookLocalState({
    required this.indexedPages,
    required this.pageCount,
    required this.lastPage,
    this.storedFileName,
    this.vectorsModel,
  });

  static const empty = BookLocalState(
    indexedPages: 0,
    pageCount: 0,
    lastPage: 1,
  );

  final int indexedPages;
  final int pageCount;
  final int lastPage;
  final String? storedFileName;
  final String? vectorsModel;

  bool isIndexed(ReferenceBook book) =>
      storedFileName == book.storedFileName &&
      pageCount == book.pageCount &&
      indexedPages >= book.pageCount;
}

enum BookAiKind {
  brief('brief', 'Brief'),
  summary('summary', 'Summary'),
  explanation('explanation', 'Explanation');

  const BookAiKind(this.storageValue, this.label);
  final String storageValue;
  final String label;
}

enum ChapterStatus {
  notStarted('notStarted', 'Not started'),
  reading('reading', 'Reading'),
  done('done', 'Done');

  const ChapterStatus(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static ChapterStatus fromStorage(String value) => values.firstWhere(
    (s) => s.storageValue == value,
    orElse: () => notStarted,
  );
}

class BookRepository {
  BookRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  AppDatabase get db => _db;

  String newId() => _uuid.v4();

  // ── Books ────────────────────────────────────────────────

  Stream<List<ReferenceBook>> watchBooks() => (_db.select(
    _db.referenceBooks,
  )..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

  Stream<ReferenceBook?> watchBook(String id) => (_db.select(
    _db.referenceBooks,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<ReferenceBook?> book(String id) => (_db.select(
    _db.referenceBooks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<ReferenceBook>> watchBooksForSubject(String subjectId) {
    final query = _db.select(_db.referenceBooks).join([
      innerJoin(
        _db.referenceBookSubjects,
        _db.referenceBookSubjects.bookId.equalsExp(_db.referenceBooks.id),
      ),
    ])..where(_db.referenceBookSubjects.subjectId.equals(subjectId));
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.referenceBooks)],
    );
  }

  Stream<List<Subject>> watchSubjectsForBook(String bookId) {
    final query = _db.select(_db.subjects).join([
      innerJoin(
        _db.referenceBookSubjects,
        _db.referenceBookSubjects.subjectId.equalsExp(_db.subjects.id),
      ),
    ])..where(_db.referenceBookSubjects.bookId.equals(bookId));
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.subjects)],
    );
  }

  Future<List<Subject>> subjectsForBook(String bookId) =>
      watchSubjectsForBook(bookId).first;

  Future<void> createBook({
    required String id,
    required String title,
    String? author,
    required String originalFileName,
    required String storedFileName,
    required int pageCount,
    required List<DetectedChapter> chapters,
    List<String> subjectIds = const [],
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db
          .into(_db.referenceBooks)
          .insert(
            ReferenceBooksCompanion.insert(
              id: id,
              title: title,
              author: Value(author),
              originalFileName: originalFileName,
              storedFileName: storedFileName,
              pageCount: pageCount,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await replaceChapters(id, chapters);
      for (final subjectId in subjectIds) {
        await setSubjectLinked(bookId: id, subjectId: subjectId, linked: true);
      }
    });
  }

  Future<void> renameBook(ReferenceBook book, String title, String? author) =>
      _db
          .update(_db.referenceBooks)
          .replace(
            book.copyWith(
              title: title,
              author: Value(author),
              updatedAt: DateTime.now(),
            ),
          );

  /// Removes the book and every synced row that belongs to it.
  Future<void> deleteBook(String id) => _db.transaction(() async {
    final quizzes = await (_db.select(
      _db.referenceBookQuizzes,
    )..where((t) => t.bookId.equals(id))).get();
    for (final quiz in quizzes) {
      await _db.deleteQuestionSet(quiz.questionSetId);
    }
    await (_db.delete(_db.referenceBooks)..where((t) => t.id.equals(id))).go();
    await clearLocal(id);
  });

  Future<void> setSubjectLinked({
    required String bookId,
    required String subjectId,
    required bool linked,
  }) async {
    await (_db.delete(_db.referenceBookSubjects)..where(
          (t) => t.bookId.equals(bookId) & t.subjectId.equals(subjectId),
        ))
        .go();
    if (linked) {
      await _db
          .into(_db.referenceBookSubjects)
          .insert(
            ReferenceBookSubjectsCompanion.insert(
              id: newId(),
              bookId: bookId,
              subjectId: subjectId,
              createdAt: DateTime.now(),
            ),
          );
    }
  }

  // ── Chapters ─────────────────────────────────────────────

  Stream<List<ReferenceBookChapter>> watchChapters(String bookId) =>
      (_db.select(_db.referenceBookChapters)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<ReferenceBookChapter>> chapters(String bookId) =>
      watchChapters(bookId).first;

  Stream<ReferenceBookChapter?> watchChapter(String id) => (_db.select(
    _db.referenceBookChapters,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> replaceChapters(
    String bookId,
    List<DetectedChapter> chapters,
  ) async {
    await (_db.delete(
      _db.referenceBookChapters,
    )..where((t) => t.bookId.equals(bookId))).go();
    final now = DateTime.now();
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      await _db
          .into(_db.referenceBookChapters)
          .insert(
            ReferenceBookChaptersCompanion.insert(
              id: newId(),
              bookId: bookId,
              title: c.title.length > 300 ? c.title.substring(0, 300) : c.title,
              level: Value(c.level),
              startPage: c.startPage,
              endPage: c.endPage,
              sortOrder: i,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> setChapterStatus(
    ReferenceBookChapter chapter,
    ChapterStatus status,
  ) => _db
      .update(_db.referenceBookChapters)
      .replace(
        chapter.copyWith(
          status: status.storageValue,
          updatedAt: DateTime.now(),
        ),
      );

  // ── AI items ─────────────────────────────────────────────

  Stream<List<ReferenceBookAiItem>> watchAiItems(String bookId) =>
      (_db.select(_db.referenceBookAiItems)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([(t) => OrderingTerm.desc(t.version)]))
          .watch();

  Future<ReferenceBookAiItem?> latestAiItem({
    required String bookId,
    required BookAiKind kind,
    required String scopeKey,
  }) =>
      (_db.select(_db.referenceBookAiItems)
            ..where(
              (t) =>
                  t.bookId.equals(bookId) &
                  t.kind.equals(kind.storageValue) &
                  t.scopeKey.equals(scopeKey),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.version),
              (t) => OrderingTerm.desc(t.createdAt),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<ReferenceBookAiItem> addAiItem({
    required String bookId,
    String? chapterId,
    required BookAiKind kind,
    required String scopeKey,
    required int startPage,
    required int endPage,
    required String content,
    String? provider,
    String? model,
  }) {
    if (content.trim().isEmpty) throw ArgumentError.value(content, 'content');
    return _db.transaction(() async {
      final latest = await latestAiItem(
        bookId: bookId,
        kind: kind,
        scopeKey: scopeKey,
      );
      final id = newId();
      await _db
          .into(_db.referenceBookAiItems)
          .insert(
            ReferenceBookAiItemsCompanion.insert(
              id: id,
              bookId: bookId,
              chapterId: Value(chapterId),
              kind: kind.storageValue,
              scopeKey: scopeKey,
              startPage: startPage,
              endPage: endPage,
              content: content.trim(),
              version: (latest?.version ?? 0) + 1,
              provider: Value(provider),
              model: Value(model),
              createdAt: DateTime.now(),
            ),
          );
      return (_db.select(
        _db.referenceBookAiItems,
      )..where((t) => t.id.equals(id))).getSingle();
    });
  }

  Future<void> deleteAiItem(String id) => (_db.delete(
    _db.referenceBookAiItems,
  )..where((t) => t.id.equals(id))).go();

  // ── Notes ────────────────────────────────────────────────

  Stream<List<ReferenceBookNote>> watchNotes(String bookId) =>
      (_db.select(_db.referenceBookNotes)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.pageNumber),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Future<void> addNote({
    required String bookId,
    required int page,
    required String title,
    String content = '',
    String? selectedText,
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.referenceBookNotes)
        .insert(
          ReferenceBookNotesCompanion.insert(
            id: newId(),
            bookId: bookId,
            pageNumber: page,
            title: title,
            content: Value(content),
            selectedText: Value(selectedText),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateNote(
    ReferenceBookNote note, {
    required String title,
    required String content,
  }) => _db
      .update(_db.referenceBookNotes)
      .replace(
        note.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> deleteNote(String id) =>
      (_db.delete(_db.referenceBookNotes)..where((t) => t.id.equals(id))).go();

  // ── Chat ─────────────────────────────────────────────────

  Stream<List<ReferenceBookMessage>> watchMessages(String bookId) =>
      (_db.select(_db.referenceBookMessages)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<ReferenceBookMessage>> messages(String bookId) =>
      watchMessages(bookId).first;

  Future<void> addMessage({
    required String bookId,
    required String role,
    required String content,
    List<int>? sourcePages,
    String? provider,
    String? model,
  }) => _db
      .into(_db.referenceBookMessages)
      .insert(
        ReferenceBookMessagesCompanion.insert(
          id: newId(),
          bookId: bookId,
          role: role,
          content: content,
          sourcePages: Value(
            sourcePages == null ? null : jsonEncode(sourcePages),
          ),
          provider: Value(provider),
          model: Value(model),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> clearMessages(String bookId) => (_db.delete(
    _db.referenceBookMessages,
  )..where((t) => t.bookId.equals(bookId))).go();

  // ── Lecture links ────────────────────────────────────────

  Stream<List<ReferenceBookLink>> watchLinks(String bookId) =>
      (_db.select(_db.referenceBookLinks)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([(t) => OrderingTerm.asc(t.startPage)]))
          .watch();

  Stream<List<ReferenceBookLink>> watchLinksForMaterials(
    List<String> materialIds,
  ) => materialIds.isEmpty
      ? Stream.value(const [])
      : (_db.select(_db.referenceBookLinks)
              ..where((t) => t.materialId.isIn(materialIds))
              ..orderBy([(t) => OrderingTerm.asc(t.startPage)]))
            .watch();

  /// Replaces the links for one (book, lecture) pair.
  Future<void> replaceLinks({
    required String bookId,
    required String materialId,
    required List<
      ({int start, int end, BookLinkPriority priority, String? reason})
    >
    ranges,
  }) => _db.transaction(() async {
    await (_db.delete(_db.referenceBookLinks)..where(
          (t) => t.bookId.equals(bookId) & t.materialId.equals(materialId),
        ))
        .go();
    final now = DateTime.now();
    for (final r in ranges) {
      await _db
          .into(_db.referenceBookLinks)
          .insert(
            ReferenceBookLinksCompanion.insert(
              id: newId(),
              bookId: bookId,
              materialId: materialId,
              startPage: r.start,
              endPage: r.end,
              priority: r.priority.storageValue,
              reason: Value(r.reason),
              createdAt: now,
            ),
          );
    }
  });

  /// Book ranges for one lecture PDF, with their books.
  Stream<List<(ReferenceBookLink, ReferenceBook)>> watchLinksForMaterial(
    String materialId,
  ) {
    final query =
        _db.select(_db.referenceBookLinks).join([
            innerJoin(
              _db.referenceBooks,
              _db.referenceBooks.id.equalsExp(_db.referenceBookLinks.bookId),
            ),
          ])
          ..where(_db.referenceBookLinks.materialId.equals(materialId))
          ..orderBy([OrderingTerm.asc(_db.referenceBookLinks.startPage)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          (
            r.readTable(_db.referenceBookLinks),
            r.readTable(_db.referenceBooks),
          ),
      ],
    );
  }

  Future<void> setLinkDone(ReferenceBookLink link, bool done) =>
      _db.update(_db.referenceBookLinks).replace(link.copyWith(done: done));

  Future<void> updateLink(
    ReferenceBookLink link, {
    required int start,
    required int end,
    required BookLinkPriority priority,
  }) => _db
      .update(_db.referenceBookLinks)
      .replace(
        link.copyWith(
          startPage: start,
          endPage: end,
          priority: priority.storageValue,
        ),
      );

  Future<void> deleteLink(String id) =>
      (_db.delete(_db.referenceBookLinks)..where((t) => t.id.equals(id))).go();

  // ── Quizzes ──────────────────────────────────────────────

  Stream<List<QuestionSet>> watchChapterQuizzes(String chapterId) {
    final query = _db.select(_db.questionSets).join([
      innerJoin(
        _db.referenceBookQuizzes,
        _db.referenceBookQuizzes.questionSetId.equalsExp(_db.questionSets.id),
      ),
    ])..where(_db.referenceBookQuizzes.chapterId.equals(chapterId));
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.questionSets)],
    );
  }

  Future<void> linkQuiz({
    required String bookId,
    required String chapterId,
    required String questionSetId,
  }) => _db
      .into(_db.referenceBookQuizzes)
      .insert(
        ReferenceBookQuizzesCompanion.insert(
          id: newId(),
          bookId: bookId,
          chapterId: chapterId,
          questionSetId: questionSetId,
          createdAt: DateTime.now(),
        ),
      );

  // ── Device-local index ───────────────────────────────────

  Stream<BookLocalState> watchLocalState(String bookId) => _db
      .customSelect(
        'SELECT * FROM local_book_state WHERE book_id = ?',
        variables: [Variable(bookId)],
        readsFrom: {_db.referenceBooks},
      )
      .watch()
      .map((rows) => rows.isEmpty ? BookLocalState.empty : _state(rows.first));

  Future<BookLocalState> localState(String bookId) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM local_book_state WHERE book_id = ?',
          variables: [Variable(bookId)],
        )
        .getSingleOrNull();
    return row == null ? BookLocalState.empty : _state(row);
  }

  static BookLocalState _state(QueryRow row) => BookLocalState(
    indexedPages: row.read<int>('indexed_pages'),
    pageCount: row.read<int>('page_count'),
    lastPage: row.read<int>('last_page'),
    storedFileName: row.readNullable<String>('stored_file_name'),
    vectorsModel: row.readNullable<String>('vectors_model'),
  );

  Future<void> _ensureState(String bookId) => _db.customStatement(
    'INSERT OR IGNORE INTO local_book_state (book_id) VALUES (?)',
    [bookId],
  );

  /// Local state lives outside Drift tables, so touching the books table
  /// notifies [watchLocalState] listeners.
  void _notify() =>
      _db.notifyUpdates({TableUpdate.onTable(_db.referenceBooks)});

  Future<void> saveLastPage(String bookId, int page) async {
    await _ensureState(bookId);
    await _db.customStatement(
      'UPDATE local_book_state SET last_page = ? WHERE book_id = ?',
      [page, bookId],
    );
  }

  Future<void> startIndex(ReferenceBook book) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM local_book_pages WHERE book_id = ?',
        [book.id],
      );
      await _db.customStatement(
        'DELETE FROM local_book_vectors WHERE book_id = ?',
        [book.id],
      );
      await _ensureState(book.id);
      await _db.customStatement(
        'UPDATE local_book_state SET stored_file_name = ?, page_count = ?, '
        'indexed_pages = 0, vectors_model = NULL WHERE book_id = ?',
        [book.storedFileName, book.pageCount, book.id],
      );
    });
    _notify();
  }

  Future<void> savePages(String bookId, List<BookPage> pages) async {
    await _db.transaction(() async {
      for (final page in pages) {
        await _db.customStatement(
          'INSERT OR REPLACE INTO local_book_pages (book_id, page, text) '
          'VALUES (?, ?, ?)',
          [bookId, page.page, page.text],
        );
      }
      await _db.customStatement(
        'UPDATE local_book_state SET indexed_pages = '
        '(SELECT COUNT(*) FROM local_book_pages WHERE book_id = ?) '
        'WHERE book_id = ?',
        [bookId, bookId],
      );
    });
    _notify();
  }

  Future<List<BookPage>> pages(String bookId, {int? start, int? end}) async {
    final rows = await _db
        .customSelect(
          'SELECT page, text FROM local_book_pages WHERE book_id = ? '
          'AND page BETWEEN ? AND ? ORDER BY page',
          variables: [
            Variable(bookId),
            Variable(start ?? 1),
            Variable(end ?? 1 << 30),
          ],
        )
        .get();
    return [
      for (final r in rows)
        BookPage(r.read<int>('page'), r.read<String>('text')),
    ];
  }

  Future<void> saveVectors(
    String bookId,
    String model,
    Map<int, List<double>> vectors,
  ) async {
    await _db.transaction(() async {
      for (final entry in vectors.entries) {
        await _db.customStatement(
          'INSERT OR REPLACE INTO local_book_vectors '
          '(book_id, page, model, vector) VALUES (?, ?, ?, ?)',
          [bookId, entry.key, model, _encode(entry.value)],
        );
      }
    });
  }

  Future<void> finishVectors(String bookId, String model) async {
    await _db.customStatement(
      'UPDATE local_book_state SET vectors_model = ? WHERE book_id = ?',
      [model, bookId],
    );
    _notify();
  }

  Future<Set<int>> vectorPages(String bookId, String model) async {
    final rows = await _db
        .customSelect(
          'SELECT page FROM local_book_vectors WHERE book_id = ? AND model = ?',
          variables: [Variable(bookId), Variable(model)],
        )
        .get();
    return {for (final r in rows) r.read<int>('page')};
  }

  Future<Map<int, List<double>>> vectors(String bookId, String model) async {
    final rows = await _db
        .customSelect(
          'SELECT page, vector FROM local_book_vectors '
          'WHERE book_id = ? AND model = ?',
          variables: [Variable(bookId), Variable(model)],
        )
        .get();
    return {
      for (final r in rows)
        r.read<int>('page'): _decode(r.read<Uint8List>('vector')),
    };
  }

  Future<void> clearLocal(String bookId) async {
    for (final table in const [
      'local_book_pages',
      'local_book_vectors',
      'local_book_state',
    ]) {
      await _db.customStatement('DELETE FROM $table WHERE book_id = ?', [
        bookId,
      ]);
    }
  }

  static Uint8List _encode(List<double> values) =>
      Float32List.fromList(values).buffer.asUint8List();

  static List<double> _decode(Uint8List bytes) => Float32List.view(
    Uint8List.fromList(bytes).buffer,
  ).toList(growable: false);
}
