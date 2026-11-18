import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/app/routes.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/core/navigation/study_navigator.dart';
import 'package:study_vault/core/storage/study_vault_paths.dart';
import 'package:study_vault/core/theme/app_spacing.dart';
import 'package:study_vault/features/search/data/file_search_indexer.dart';
import 'package:study_vault/features/search/data/search_providers.dart';
import 'package:study_vault/features/search/data/study_search_service.dart';
import 'package:study_vault/features/search/domain/study_search_result.dart';
import 'package:study_vault/features/search/domain/study_search_scope.dart';
import 'package:study_vault/features/search/presentation/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory directory;
  late StudySearchService search;
  late Map<String, File> files;
  final now = DateTime.utc(2026, 11, 4, 12);
  const scopeA = StudySearchScope.class_(id: 'ca', title: 'Class A');
  const subjectA = StudySearchScope.subject(id: 'sa', title: 'Subject A');
  const lessonA = StudySearchScope.lesson(id: 'la', title: 'Lesson A');
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp(
      'study-vault-search-test-',
    );
    StudyVaultPaths.useLibraryRoot(directory);
    files = {};
    search = StudySearchService(db);
  });
  tearDown(() async {
    await db.close();
    StudyVaultPaths.useLibraryRoot(null);
    await directory.delete(recursive: true);
  });
  Future<void> hierarchy(String suffix, {String lessonName = 'Lecture'}) async {
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c$suffix',
        name: 'Class $suffix',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's$suffix',
        classId: 'c$suffix',
        name: 'Subject $suffix',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l$suffix',
        subjectId: 's$suffix',
        name: lessonName,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> material(
    String suffix, {
    String mime = 'application/pdf',
    String text = 'fixture',
  }) async {
    final file = File('${directory.path}/m$suffix')..writeAsStringSync(text);
    files['m$suffix'] = file;
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'm$suffix',
        lessonId: 'l$suffix',
        title: 'Lecture attachment $suffix',
        originalFileName: 'lecture.pdf',
        storedFileName: 'm$suffix',
        mimeType: Value(mime),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  FileSearchIndexer indexer(
    Stream<IndexedSearchPage> Function(String, String) extract,
  ) {
    final value = FileSearchIndexer(
      db,
      resolvePath: (m) async => files[m.id]!.path,
      extract: extract,
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    'content-only PDF matches include the correct page and hierarchy',
    () async {
      await hierarchy('a');
      await material('a');
      final index = indexer((path, mime) async* {
        yield const IndexedSearchPage(1, 'Introduction');
        yield IndexedSearchPage(
          7,
          '${'Unrelated introduction. ' * 40}Gradient descent updates the weights.',
        );
      });
      await index.ensureIndexed(scopeA);
      final results = await search.search(
        query: 'gradient descent',
        scope: scopeA,
      );
      final hit = results.singleWhere((r) => r.pageNumber == 7);
      expect(hit.kind, StudyEntityKind.material);
      expect(hit.materialId, 'ma');
      expect(hit.classId, 'ca');
      expect(hit.subjectId, 'sa');
      expect(hit.lessonId, 'la');
      expect(hit.matchedSnippet, contains('Gradient descent'));
      expect(hit.matchedSnippet!.length, lessThan(250));
      expect(hit.subtitle, 'PDF · page 7');
      expect(
        (await search.search(
          query: 'gradient descent',
          scope: const StudySearchScope.class_(id: 'cb', title: 'Other'),
        )),
        isEmpty,
      );
    },
  );

  test('FTS matches token prefixes and multiple terms safely', () async {
    await hierarchy('a');
    await material('a');
    final index = indexer((_, _) async* {
      yield const IndexedSearchPage(
        3,
        'Gradient descent improves regression models. C++ uses 100% effort.',
      );
    });
    await index.ensureIndexed(scopeA);
    expect(
      (await search.search(
        query: 'grad regress',
        scope: scopeA,
      )).single.pageNumber,
      3,
    );
    expect(await search.search(query: 'C++', scope: scopeA), hasLength(1));
    expect(await search.search(query: '100%', scope: scopeA), hasLength(1));
    expect(
      await search.search(
        query: "\" OR * ' DROP TABLE lessons;",
        scope: scopeA,
      ),
      isEmpty,
    );
    expect(await db.select(db.lessons).get(), hasLength(1));
  });

  test('Persian content matches Arabic Yeh and Kaf variants', () async {
    await hierarchy('a');
    await material('a');
    final index = indexer((_, _) async* {
      yield const IndexedSearchPage(2, 'یادگیری ماشین و کتاب دانشگاه');
    });
    await index.ensureIndexed(scopeA);
    expect(await search.search(query: 'يادگيري', scope: scopeA), hasLength(1));
    expect(await search.search(query: 'كتاب', scope: scopeA), hasLength(1));
  });

  test(
    'unchanged files reuse text and overlapping scans share one extraction',
    () async {
      await hierarchy('a');
      await material('a');
      var calls = 0;
      final gate = Completer<void>();
      final started = Completer<void>();
      final index = indexer((_, _) async* {
        calls++;
        started.complete();
        await gate.future;
        yield const IndexedSearchPage(1, 'Cached contents');
      });
      final first = index.ensureIndexed(scopeA);
      await started.future;
      final second = index.ensureIndexed(scopeA);
      gate.complete();
      await Future.wait([first, second]);
      await index.ensureIndexed(subjectA);
      expect(calls, 1);
      expect(index.progress.running, isFalse);
    },
  );

  test('replaced file contents remove old FTS terms', () async {
    await hierarchy('a');
    await material('a', text: 'Old token');
    final index = indexer((path, _) async* {
      yield IndexedSearchPage(1, await File(path).readAsString());
    });
    await index.ensureIndexed(scopeA);
    expect(await search.search(query: 'Old token'), hasLength(1));
    await files['ma']!.writeAsString('Replacement concept with different size');
    await index.ensureIndexed(scopeA);
    expect(await search.search(query: 'Old token'), isEmpty);
    expect(await search.search(query: 'Replacement concept'), hasLength(1));
  });

  test(
    'metadata revision changes hide stale indexed text before reindexing',
    () async {
      await hierarchy('a');
      await material('a');
      final index = indexer((_, _) async* {
        yield const IndexedSearchPage(1, 'Old searchable term');
      });
      await index.ensureIndexed(scopeA);
      await (db.update(
        db.lessonMaterials,
      )..where((t) => t.id.equals('ma'))).write(
        LessonMaterialsCompanion(
          updatedAt: Value(now.add(const Duration(seconds: 2))),
        ),
      );
      expect(await search.search(query: 'searchable'), isEmpty);
    },
  );

  test('deleting a material cascades page cache and FTS rows', () async {
    await hierarchy('a');
    await material('a');
    final index = indexer((_, _) async* {
      yield const IndexedSearchPage(1, 'Deleted searchable term');
    });
    await index.ensureIndexed(scopeA);
    await (db.delete(db.lessonMaterials)..where((t) => t.id.equals('ma'))).go();
    expect(await search.search(query: 'searchable'), isEmpty);
    expect(
      (await db
              .customSelect('SELECT count(*) AS n FROM local_search_pages')
              .getSingle())
          .read<int>('n'),
      0,
    );
    expect(
      (await db
              .customSelect(
                "SELECT count(*) AS n FROM local_search_fts WHERE local_search_fts MATCH 'searchable'",
              )
              .getSingle())
          .read<int>('n'),
      0,
    );
  });

  test(
    'missing and image-only PDFs are reported without hiding title results',
    () async {
      await hierarchy('a');
      await material('a');
      var fail = false;
      final index = indexer((_, _) async* {
        if (fail) throw const FormatException('Cannot read');
        yield const IndexedSearchPage(1, '');
      });
      await index.ensureIndexed(scopeA);
      expect(index.progress.withoutText, 1);
      await files['ma']!.delete();
      fail = true;
      await index.ensureIndexed(scopeA);
      expect(index.progress.unavailable, 1);
      expect(await search.search(query: 'Lecture attachment'), hasLength(1));
    },
  );

  test('failed extraction never leaves a completed partial index', () async {
    await hierarchy('a');
    await material('a');
    final index = indexer((_, _) async* {
      for (var i = 1; i <= 33; i++) {
        yield IndexedSearchPage(i, 'Partial token $i');
      }
      throw const FormatException('Corrupt final page');
    });
    await index.ensureIndexed(scopeA);
    expect(index.progress.unavailable, 1);
    expect(await search.search(query: 'Partial token'), isEmpty);
  });

  test('Markdown chunks overlap and do not invent PDF page numbers', () async {
    await hierarchy('a');
    await material(
      'a',
      mime: 'text/markdown',
      text: '${'x ' * 2998}gradient descent\nMore content',
    );
    final index = FileSearchIndexer(
      db,
      resolvePath: (m) async => files[m.id]!.path,
    );
    addTearDown(index.dispose);
    await index.ensureIndexed(scopeA);
    final hits = await search.search(query: 'gradient descent');
    expect(hits, hasLength(1));
    expect(hits.single.pageNumber, isNull);
    expect(hits.single.subtitle, 'Inside text document');
  });

  test('literal LIKE fallback remains functional without FTS', () async {
    await hierarchy('a');
    await material('a');
    final index = indexer((_, _) async* {
      yield const IndexedSearchPage(1, 'Fallback searchable phrase');
    });
    await index.ensureIndexed(scopeA);
    await db.customStatement('DROP TRIGGER local_search_pages_ai');
    await db.customStatement('DROP TRIGGER local_search_pages_ad');
    await db.customStatement('DROP TRIGGER local_search_pages_au');
    await db.customStatement('DROP TABLE local_search_fts');
    expect(
      await search.search(query: 'searchable phrase', scope: scopeA),
      hasLength(1),
    );
  });

  test(
    'scope is applied before result limits and includes child notes and cards',
    () async {
      await hierarchy('b', lessonName: 'Topic');
      for (var i = 0; i < 70; i++) {
        await db.insertLesson(
          LessonsCompanion.insert(
            id: 'other-$i',
            subjectId: 'sb',
            name: 'Topic $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await hierarchy('a', lessonName: 'Topic target');
      await db
          .into(db.studyNotes)
          .insert(
            StudyNotesCompanion.insert(
              id: 'note-a',
              lessonId: const Value('la'),
              title: 'Topic note',
              content: '[{"insert":"Topic notes\\n"}]',
              plainTextContent: const Value('Topic notes'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.flashcards)
          .insert(
            FlashcardsCompanion.insert(
              id: 'card-a',
              lessonId: const Value('la'),
              front: 'Topic question',
              back: '[]',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final hits = await search.search(query: 'Topic', scope: scopeA);
      expect(hits.map((h) => h.id), containsAll(['la', 'note-a', 'card-a']));
      expect(
        hits.any((h) => h.id == 'lb' || h.id.startsWith('other-')),
        isFalse,
      );
      expect(
        (await search.search(query: 'Topic', scope: lessonA)).map((h) => h.id),
        containsAll(['la', 'note-a', 'card-a']),
      );
    },
  );

  test(
    'AI materials search the latest version rather than obsolete text',
    () async {
      await hierarchy('a');
      await material('a');
      for (var version = 1; version <= 2; version++) {
        await db
            .into(db.pdfAiMaterials)
            .insert(
              PdfAiMaterialsCompanion.insert(
                id: 'ai-$version',
                materialId: 'ma',
                type: 'summary',
                content: version == 1
                    ? 'Obsolete explanation'
                    : 'Current gradient explanation',
                version: version,
                generatedAt: now,
                sourceFingerprint: 'fingerprint',
              ),
            );
      }
      expect(await search.search(query: 'Obsolete', scope: scopeA), isEmpty);
      final result = (await search.search(
        query: 'gradient',
        scope: lessonA,
      )).single;
      expect(result.kind, StudyEntityKind.aiMaterial);
      expect(result.id, 'ai-2');
      expect(result.materialId, 'ma');
    },
  );

  test(
    'Course Review and indexed books respect their subject associations',
    () async {
      await hierarchy('a');
      await hierarchy('b');
      await db
          .into(db.courseReviewEntries)
          .insert(
            CourseReviewEntriesCompanion.insert(
              id: 'review',
              subjectId: 'sa',
              part: 'document',
              content: 'Gradient study guide',
              version: 1,
              createdAt: now,
            ),
          );
      await db
          .into(db.referenceBooks)
          .insert(
            ReferenceBooksCompanion.insert(
              id: 'book',
              title: 'Textbook',
              originalFileName: 'textbook.pdf',
              storedFileName: 'book.pdf',
              pageCount: 20,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.referenceBookSubjects)
          .insert(
            ReferenceBookSubjectsCompanion.insert(
              id: 'book-subject',
              bookId: 'book',
              subjectId: 'sa',
              createdAt: now,
            ),
          );
      await db.customStatement(
        'INSERT INTO local_book_pages(book_id,page,text) VALUES(?,?,?)',
        ['book', 12, 'Gradient textbook example'],
      );
      final hits = await search.search(query: 'Gradient', scope: subjectA);
      expect(
        hits.map((h) => h.kind),
        containsAll([StudyEntityKind.book, StudyEntityKind.courseReview]),
      );
      expect(
        hits.singleWhere((h) => h.kind == StudyEntityKind.book).pageNumber,
        12,
      );
      expect(
        await search.search(
          query: 'Gradient',
          scope: const StudySearchScope.subject(id: 'sb', title: 'B'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'file index tables stay out of Drift and synchronized table exports',
    () async {
      await db.customSelect('SELECT 1').get();
      expect(
        db.allTables.any((t) => t.actualTableName.startsWith('local_search_')),
        isFalse,
      );
      expect(db.schemaVersion, 24);
    },
  );

  test(
    'two search sessions keep their scope, text, and filters independent',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final global = SearchSession();
      final scoped = SearchSession(
        scope: lessonA,
        filter: SearchResultFilter.materials,
      );
      final a = container.listen(searchQueryProvider(global), (_, _) {});
      final b = container.listen(searchQueryProvider(scoped), (_, _) {});
      addTearDown(a.close);
      addTearDown(b.close);
      container
          .read(searchQueryProvider(global).notifier)
          .setQuery('Library query');
      container
          .read(searchQueryProvider(scoped).notifier)
          .setQuery('Class topic');
      expect(
        container.read(searchQueryProvider(global)).query,
        'Library query',
      );
      expect(container.read(searchQueryProvider(scoped)).query, 'Class topic');
      expect(container.read(searchQueryProvider(scoped)).scope.id, 'la');
      expect(
        container.read(searchQueryProvider(scoped)).typeFilter,
        SearchResultFilter.materials,
      );
    },
  );

  testWidgets('scoped search aligns filters and results across window sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          fileSearchIndexProgressProvider.overrideWith(
            (ref) => Stream.value(const FileSearchIndexProgress()),
          ),
          fileSearchIndexRequestProvider.overrideWith((ref, scope) async {}),
          searchResultsProvider.overrideWith(
            (ref, session) async => [
              const StudySearchResult(
                kind: StudyEntityKind.material,
                id: 'ma',
                title: 'Lecture attachment',
                breadcrumb: 'Class A › Lesson A',
                subtitle: 'PDF · page 7',
                pageNumber: 7,
                matchedSnippet: 'Gradient descent updates the weights.',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: SearchScreen(scope: lessonA)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gradient');
    await tester.pumpAndSettle();
    expect(find.text('Search Lesson A'), findsOneWidget);
    expect(find.textContaining('Gradient descent updates'), findsOneWidget);
    expect(find.textContaining('PDF · page 7'), findsOneWidget);
    final input = find.byType(TextField);
    final scopeChip = find.byType(ActionChip);
    final result = find.widgetWithText(ListTile, 'Lecture attachment');
    for (final widget in [input, scopeChip, result]) {
      expect(tester.getTopLeft(widget).dx, AppSpacing.pagePadding);
    }
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      tester.view.physicalSize = const Size(1600, 900);
      await tester.pumpAndSettle();
      final left = (1600 - AppSpacing.contentMaxWidthWide) / 2;
      for (final widget in [input, scopeChip, result]) {
        expect(tester.getTopLeft(widget).dx, left);
      }
      expect(tester.getSize(result).width, AppSpacing.contentMaxWidthWide);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('PDF content search navigation forwards the matched page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await hierarchy('a');
      await material('a');
    });
    RouteSettings? destination;
    const hit = StudySearchResult(
      kind: StudyEntityKind.material,
      id: 'ma',
      title: 'Lecture',
      breadcrumb: 'Class A',
      pageNumber: 7,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          onGenerateRoute: (settings) {
            destination = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('PDF target')),
            );
          },
          home: const _OpenHit(hit),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Open match'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(destination?.name, AppRoutes.pdfStudy);
    expect((destination?.arguments as Map)['initialPage'], '7');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _OpenHit extends ConsumerWidget {
  const _OpenHit(this.hit);
  final StudySearchResult hit;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: TextButton(
      onPressed: () => StudyNavigator.openSearchResult(context, ref, hit),
      child: const Text('Open match'),
    ),
  );
}
