import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/app/routes.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/reference_books/data/book_providers.dart';
import 'package:study_vault/features/reference_books/presentation/book_indexer.dart';
import 'package:study_vault/features/reference_books/presentation/books_shelf_screen.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';
import 'package:study_vault/features/course_review/data/course_review_repository.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';
import 'package:study_vault/features/reference_books/data/book_repository.dart';
import 'package:study_vault/features/reference_books/domain/book_chapter_detector.dart';
import 'package:study_vault/features/reference_books/domain/book_prompts.dart';
import 'package:study_vault/features/reference_books/domain/book_text_index.dart';
import 'package:study_vault/features/reference_books/domain/reading_plan.dart';
import 'package:study_vault/features/reference_books/presentation/book_markdown.dart';
import 'package:study_vault/features/reference_books/services/book_ai_service.dart';
import 'package:study_vault/features/reference_books/services/book_import_service.dart';
import 'package:study_vault/features/reference_books/services/book_search_service.dart';

const _selection = AiExecutionSelection(
  provider: AiProviderId.deepseek,
  requestedModelId: 'model',
  resolvedModelId: 'model',
);

/// 12-page book: chapter 1 = pages 1–5 (risk), chapter 2 = 6–12 (budget).
final _pages = [
  for (var i = 1; i <= 12; i++)
    BookPage(
      i,
      i == 3
          ? 'Risk management identifies risks early. A risk register lists '
                'each risk with probability and impact.'
          : i == 8
          ? 'Earned value compares planned value and actual cost to track '
                'the budget.'
          : i == 11
          ? 'Cost overruns appear when spending exceeds the baseline.'
          : 'General project text on page $i.',
    ),
];

void main() {
  group('BookTextIndex', () {
    final index = BookTextIndex.build(_pages);

    test('stems and drops stopwords', () {
      expect(BookTextIndex.tokenize('The risks were managed'), [
        'risk',
        'manag',
      ]);
      expect(BookTextIndex.stem('studies'), 'study');
    });

    test('ranks the page that explains the term first', () {
      final hits = index.search('what is a risk register?');
      expect(hits.first.page, 3);
      expect(hits.first.snippet.toLowerCase(), contains('risk register'));
    });

    test('restricts results to a page range', () {
      expect(index.search('risk', within: (start: 6, end: 12)), isEmpty);
      expect(index.search('budget', within: (start: 6, end: 12)).first.page, 8);
    });

    test('rank fusion favours pages strong in both lists', () {
      expect(
        fuseRankings([
          [1, 2, 3],
          [3, 1, 9],
        ]).take(2),
        [1, 3],
      );
    });
  });

  group('BookChapterDetector', () {
    test('uses bookmarks; sections end before the next sibling', () {
      final chapters = BookChapterDetector.detect(
        pageCount: 100,
        outline: const [
          OutlineEntry('Ch 1', 0, 1),
          OutlineEntry('1.1', 1, 2),
          OutlineEntry('1.2', 1, 20),
          OutlineEntry('Ch 2', 0, 40),
          OutlineEntry('Deep', 2, 41),
        ],
        pageText: const {},
      );
      expect(
        [for (final c in chapters) '${c.title}:${c.startPage}-${c.endPage}'],
        ['Ch 1:1-39', '1.1:2-19', '1.2:20-39', 'Ch 2:40-100'],
      );
    });

    test('falls back to "Chapter N" headings, then page blocks', () {
      final headings = BookChapterDetector.detect(
        pageCount: 30,
        outline: const [],
        pageText: {
          1: 'Preface',
          4: 'Chapter 1 Introduction\ntext',
          15: 'CHAPTER 2: Planning\nmore',
          16: 'see chapter 2 again',
        },
      );
      expect(headings.map((c) => c.title), [
        'Chapter 1: Introduction',
        'Chapter 2: Planning',
      ]);
      expect(headings.last.endPage, 30);
      final blocks = BookChapterDetector.detect(
        pageCount: 60,
        outline: const [],
        pageText: const {},
      );
      expect(blocks.map((c) => c.title), [
        'Pages 1–25',
        'Pages 26–50',
        'Pages 51–60',
      ]);
    });

    test('distrusts junk bookmarks and uses headings instead', () {
      // Mirrors a real import: out-of-order flat bookmarks, a same-page
      // collision, a "Page N" label, and wrong destinations.
      final chapters = BookChapterDetector.detect(
        pageCount: 60,
        outline: const [
          OutlineEntry('Title Page', 0, 2),
          OutlineEntry('Part III. Ending the Project', 0, 2),
          OutlineEntry('Page 154', 0, 30),
          OutlineEntry('Chapter 1', 0, 8),
          OutlineEntry('Chapter 5 Scope', 0, 20),
        ],
        pageText: {
          8: 'CHAPTER 1\nIntroduction\nFigure 1.1 Chapter 1 objectives',
          20: 'CHAPTER 5\nManaging Project Scope\nFigure 5.1 objectives',
          40: 'CHAPTER 6\nManaging Project Scheduling\nFigure 6.1 objectives',
        },
      );
      expect(
        [for (final c in chapters) '${c.title}:${c.startPage}-${c.endPage}'],
        [
          'Chapter 1: Introduction:8-19',
          'Chapter 5: Managing Project Scope:20-39',
          'Chapter 6: Managing Project Scheduling:40-60',
        ],
      );
    });

    test('skips contents pages and body-text chapter mentions', () {
      final chapters = BookChapterDetector.detect(
        pageCount: 100,
        outline: const [],
        pageText: {
          // Table of contents: several headings on one page.
          3: 'Contents\nPreface\nPART I. FOUNDATIONS\n'
              'Chapter 1. Introduction\nChapter 2. Planning',
          // Continuation page whose first lines still list headings.
          4: 'Chapter Exercises\nReferences\n'
              'PART III. EXECUTING AND ENDING THE\nPROJECT\n'
              'Chapter 11. Managing Project Execution',
          // Bare mid-sentence reference is not a chapter start.
          30: 'as well as those resources, are discussed in\n'
              'Chapter 7.\nThis chapter provides',
          10: 'PART I\nProject Management Foundations',
          15: 'CHAPTER 1\nIntroduction\nFigure 1.1 objectives',
          50: 'CHAPTER 7\nManaging Project Resources\nFigure 7.1 objectives',
          80: 'PART III\nEnding the Project',
          85: 'CHAPTER 11\nManaging Project Execution\nFigure 11.1 objectives',
        },
      );
      expect(
        [for (final c in chapters) '${c.title}:${c.level}:${c.startPage}'],
        [
          'Part I: Project Management Foundations:0:10',
          'Chapter 1: Introduction:1:15',
          'Chapter 7: Managing Project Resources:1:50',
          'Part III: Ending the Project:0:80',
          'Chapter 11: Managing Project Execution:1:85',
        ],
      );
    });
  });

  group('reading plan', () {
    test('spreads unfinished must/skim ranges across the days', () {
      final ranges = [
        for (var i = 0; i < 6; i++)
          PlanRange(
            id: '$i',
            lectureTitle: 'L$i',
            startPage: i * 20 + 1,
            endPage: i * 20 + 20,
            priority: i == 5
                ? BookLinkPriority.optional
                : i.isEven
                ? BookLinkPriority.must
                : BookLinkPriority.skim,
            done: i == 0,
          ),
      ];
      final plan = buildReadingPlan(
        ranges: ranges,
        today: DateTime(2026, 10, 1),
        examDate: DateTime(2026, 10, 5),
      );
      final scheduled = plan.days.expand((d) => d.ranges).map((r) => r.id);
      expect(scheduled, ['1', '2', '3', '4']);
      expect(plan.days.length, lessThanOrEqualTo(4));
      expect(plan.mustPages, 60);
      expect(plan.skimPages, 40);
      expect(plan.remainingEffort, closeTo(20 * 0.4 * 2 + 40, 0.01));
    });
  });

  group('prompts', () {
    test('citations and lecture ranges are parsed defensively', () {
      expect(BookPrompts.citedPages('See [p. 12] and [pp. 3–5], [p 12]'), [
        3,
        12,
      ]);
      expect(BookMarkdown.linkCitations('x [p. 4–6]'), 'x [p. 4–6](page:4)');
      final ranges = BookPrompts.parseRanges(
        'Here: {"ranges":[{"start":5,"end":9,"priority":"must"},'
        '{"start":0,"end":3},{"start":11,"end":99,"priority":"skim"}]}',
        12,
      );
      expect(
        [for (final r in ranges) '${r.start}-${r.end}:${r.priority}'],
        ['5-9:must', '11-12:skim'],
      );
      expect(
        () => BookPrompts.parseRanges('no json', 12),
        throwsFormatException,
      );
    });
  });

  testWidgets('shelf and book screen show chapters, status and tabs', (
    tester,
  ) async {
    final now = DateTime(2026);
    final book = ReferenceBook(
      id: 'b1',
      title: 'Project Management Body of Knowledge',
      originalFileName: 'b.pdf',
      storedFileName: 'b.pdf',
      pageCount: 1600,
      createdAt: now,
      updatedAt: now,
    );
    ReferenceBookChapter chapter(
      String id,
      String title,
      int s,
      int e,
      String status,
    ) => ReferenceBookChapter(
      id: id,
      bookId: 'b1',
      title: title,
      level: 0,
      startPage: s,
      endPage: e,
      sortOrder: s,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    final chapters = [
      chapter('c1', 'Introduction', 1, 800, 'done'),
      chapter('c2', 'Risk', 801, 1600, 'notStarted'),
    ];
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final overrides = [
      databaseProvider.overrideWithValue(db),
      booksProvider.overrideWith((ref) => Stream.value([book])),
      bookProvider('b1').overrideWith((ref) => Stream.value(book)),
      bookChaptersProvider('b1').overrideWith((ref) => Stream.value(chapters)),
      bookAiItemsProvider('b1').overrideWith((ref) => Stream.value(const [])),
      bookSubjectsProvider('b1').overrideWith((ref) => Stream.value(const [])),
      bookMessagesProvider('b1').overrideWith((ref) => Stream.value(const [])),
      bookLocalStateProvider('b1').overrideWith(
        (ref) => Stream.value(
          const BookLocalState(
            indexedPages: 1600,
            pageCount: 1600,
            lastPage: 1,
            storedFileName: 'b.pdf',
          ),
        ),
      ),
      bookIndexerProvider.overrideWith((ref) => _IdleIndexer(ref)),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          onGenerateRoute: onGenerateRoute,
          home: const BooksShelfScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Project Management Body of Knowledge'), findsOneWidget);
    expect(find.text('50% read'), findsOneWidget);

    await tester.tap(find.text('Project Management Body of Knowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Search ready · 1600 pages'), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    expect(find.text('pp. 801–1600'), findsOneWidget);
    for (final tab in ['Ask', 'Notes', 'Courses']) {
      expect(find.text(tab), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });

  group('services', () {
    late AppDatabase db;
    late BookRepository repository;
    late Directory root;
    late _FakeReader reader;
    late BookImportService importer;
    late _FakeClient client;
    late _FakeEmbeddings embeddings;
    late BookSearchService search;
    late BookAiService ai;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = BookRepository(db);
      root = await Directory.systemTemp.createTemp('sv_books');
      reader = _FakeReader();
      importer = BookImportService(
        repository,
        reader: reader,
        filesRoot: () async => root,
      );
      client = _FakeClient();
      embeddings = _FakeEmbeddings();
      search = BookSearchService(repository, embeddings);
      ai = BookAiService(repository, search, client);
    });

    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    Future<ReferenceBook> importAndIndex() async {
      final source = File(p.join(root.path, 'source.pdf'))
        ..writeAsBytesSync([1, 2, 3]);
      final book = await importer.importBook(
        sourcePath: source.path,
        title: 'PM Book',
      );
      await importer.indexBook(
        book,
        filePath: p.join(
          root.path,
          BookStorage.relativePath(book.id, book.storedFileName),
        ),
      );
      return book;
    }

    test(
      'import copies the file, builds chapters, indexes resumably',
      () async {
        final source = File(p.join(root.path, 'source.pdf'))
          ..writeAsBytesSync([1, 2, 3]);
        final book = await importer.importBook(
          sourcePath: source.path,
          title: 'PM Book',
        );
        final stored = File(
          p.join(
            root.path,
            BookStorage.relativePath(book.id, book.storedFileName),
          ),
        );
        expect(stored.existsSync(), isTrue);
        expect(book.pageCount, 12);
        expect((await repository.chapters(book.id)).map((c) => c.title), [
          'Risk',
          'Budget',
        ]);

        var calls = 0;
        await importer.indexBook(
          book,
          filePath: stored.path,
          isCancelled: () => ++calls >= 1,
        );
        expect((await repository.localState(book.id)).indexedPages, 5);
        await importer.indexBook(book, filePath: stored.path);
        final state = await repository.localState(book.id);
        expect(state.indexedPages, 12);
        expect(state.isIndexed(book), isTrue);
        expect(reader.reads, [1, 6]);
      },
    );

    test('ask retrieves pages, cites them and stores the turn', () async {
      final book = await importAndIndex();
      client.outputs.addAll([
        'risk register, probability',
        'A register [p. 3].',
      ]);
      await ai.ask(
        book: book,
        question: 'What is a risk register?',
        selection: _selection,
      );
      final messages = await repository.messages(book.id);
      expect(messages.map((m) => m.role), ['user', 'assistant']);
      expect(messages.last.content, 'A register [p. 3].');
      expect(messages.last.sourcePages, contains('3'));
      final sent = client.messages.last.map((m) => m['content']).join();
      expect(sent, contains('--- Page 3 (Risk) ---'));
      expect(sent, isNot(contains('--- Page 8')));
    });

    test('ask refuses before indexing finishes', () async {
      final source = File(p.join(root.path, 's.pdf'))..writeAsBytesSync([1]);
      final book = await importer.importBook(
        sourcePath: source.path,
        title: 'B',
      );
      await expectLater(
        ai.ask(book: book, question: 'risk?', selection: _selection),
        throwsStateError,
      );
    });

    test(
      'chapter items version per chapter; explanations are bounded',
      () async {
        final book = await importAndIndex();
        final chapter = (await repository.chapters(book.id)).first;
        client.outputs.addAll(['Brief one', 'Brief two']);
        for (var i = 0; i < 2; i++) {
          await ai.generateChapterItem(
            book: book,
            chapter: chapter,
            kind: BookAiKind.brief,
            selection: _selection,
          );
        }
        final latest = await repository.latestAiItem(
          bookId: book.id,
          kind: BookAiKind.brief,
          scopeKey: chapter.id,
        );
        expect(latest!.version, 2);
        expect(latest.content, 'Brief two');
        expect(client.messages.last[1]['content'], contains('--- Page 5 ---'));
        expect(
          client.messages.last[1]['content'],
          isNot(contains('--- Page 6')),
        );
        await expectLater(
          ai.explainPages(
            book: book,
            startPage: 1,
            endPage: 40,
            selection: _selection,
          ),
          throwsStateError,
        );
      },
    );

    test('lecture matching saves validated ranges', () async {
      final book = await importAndIndex();
      await _seedLecture(db);
      await repository.setSubjectLinked(
        bookId: book.id,
        subjectId: 's1',
        linked: true,
      );
      final lecture = (await CourseReviewRepository(
        db,
      ).load('s1'))!.sources.single;
      client.outputs.add(
        '{"ranges":[{"start":6,"end":9,"priority":"must","reason":"EV"},'
        '{"start":11,"end":12,"priority":"skim"}]}',
      );
      expect(
        await ai.mapLecture(
          book: book,
          lecture: lecture,
          selection: _selection,
        ),
        2,
      );
      final links = await repository.watchLinks(book.id).first;
      expect(
        [for (final l in links) '${l.startPage}-${l.endPage}:${l.priority}'],
        ['6-9:must', '11-12:skim'],
      );
      expect(client.messages.last[1]['content'], contains('BOOK CONTENTS'));
      expect(client.messages.last[1]['content'], contains('earned value'));

      await db.deleteLessonMaterial('m1');
      expect(await repository.watchLinks(book.id).first, isEmpty);
    });

    test('smart search fuses semantic-only matches', () async {
      final book = await importAndIndex();
      await search.buildVectors(book.id);
      expect(
        (await repository.localState(book.id)).vectorsModel,
        embeddings.model,
      );
      final hits = await search.search(book.id, 'overspending');
      expect(hits.map((h) => h.page), contains(11));
    });

    test('book files sync like lesson materials; delete cascades', () async {
      final book = await importAndIndex();
      expect(
        cloudFilePath('reference_books', {
          'id': book.id,
          'stored_file_name': book.storedFileName,
        }),
        'books/${book.id}/${book.storedFileName}',
      );
      final schema = await CloudSyncSchema.load(db);
      final row = {for (final e in book.toJson().entries) e.key: e.value};
      expect(row, isNotEmpty);
      expect(
        schema.tables.keys,
        containsAll([
          'reference_books',
          'reference_book_chapters',
          'reference_book_ai_items',
          'reference_book_links',
        ]),
      );
      expect(schema.tables.keys.where((t) => t.startsWith('local_')), isEmpty);

      await repository.addNote(bookId: book.id, page: 3, title: 'n');
      await repository.deleteBook(book.id);
      expect(await repository.chapters(book.id), isEmpty);
      expect(await repository.watchNotes(book.id).first, isEmpty);
      expect((await repository.localState(book.id)).indexedPages, 0);
    });
  });
}

Future<void> _seedLecture(AppDatabase db) async {
  final now = DateTime(2026);
  await db.insertClass(
    ClassesCompanion.insert(
      id: 'c1',
      name: 'C',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertSubject(
    SubjectsCompanion.insert(
      id: 's1',
      classId: 'c1',
      name: 'PM',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLesson(
    LessonsCompanion.insert(
      id: 'l1',
      subjectId: 's1',
      name: 'Costs',
      sortOrder: const Value(0),
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLessonMaterial(
    LessonMaterialsCompanion.insert(
      id: 'm1',
      lessonId: 'l1',
      title: 'Lect-05',
      originalFileName: 'l.pdf',
      storedFileName: 'l.pdf',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertPdfAiMaterialVersion(
    materialId: 'm1',
    type: 'summary',
    builder: (version) => PdfAiMaterialsCompanion.insert(
      id: 'sum',
      materialId: 'm1',
      type: 'summary',
      content: 'Lecture on earned value and budget control.',
      version: version,
      generatedAt: now,
      sourceFingerprint: 'fp',
    ),
  );
}

class _IdleIndexer extends BookIndexer {
  _IdleIndexer(super.ref);

  @override
  Future<void> ensureIndexed(
    ReferenceBook book, {
    bool detectHeadings = false,
  }) async {}
}

class _FakeReader implements BookPdfReader {
  final reads = <int>[];

  @override
  Future<int> pageCount(String filePath) async => _pages.length;

  @override
  Future<List<OutlineEntry>> outline(String filePath) async => const [
    OutlineEntry('Risk', 0, 1),
    OutlineEntry('Budget', 0, 6),
  ];

  @override
  Future<void> readPages(
    String filePath, {
    required int fromPage,
    required int batchSize,
    required Future<bool> Function(List<BookPage> batch) onBatch,
  }) async {
    reads.add(fromPage);
    final rest = _pages.where((pg) => pg.page >= fromPage).toList();
    for (var i = 0; i < rest.length; i += 5) {
      final end = i + 5 > rest.length ? rest.length : i + 5;
      if (!await onBatch(rest.sublist(i, end))) return;
    }
  }
}

class _FakeClient implements PdfAiCompletionClient {
  final outputs = <String>[];
  final messages = <List<Map<String, String>>>[];

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) async {
    this.messages.add(messages);
    return PdfAiCompletion(
      markdown: outputs.removeAt(0),
      provider: 'deepseek',
      model: 'model',
    );
  }
}

/// Puts "overspending" next to page 11's cost-overrun text in vector space.
class _FakeEmbeddings implements BookEmbeddingClient {
  @override
  String get model => 'fake@3';

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool query,
  }) async => [
    for (final t in texts)
      t.contains('overrun') || t.contains('overspending')
          ? [1.0, 0, 0]
          : t.contains('risk')
          ? [0, 1.0, 0]
          : [0, 0, 1.0],
  ];
}
