import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/course_review/presentation/course_review_screen.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/course_review/data/course_review_providers.dart';
import 'package:study_vault/features/reference_books/data/book_providers.dart';
import 'package:study_vault/features/course_review/domain/course_review_models.dart';
import 'package:study_vault/features/course_review/domain/course_review_prompts.dart';
import 'package:study_vault/features/course_review/services/course_review_service.dart';
import 'package:study_vault/features/manual_entry/data/manual_entry_providers.dart';
import 'package:study_vault/features/manual_entry/domain/manual_entry_models.dart';
import 'package:study_vault/features/manual_entry/domain/manual_entry_plan.dart';
import 'package:study_vault/features/manual_entry/services/manual_entry_import_service.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';

const _selection = AiExecutionSelection(
  provider: AiProviderId.deepseek,
  requestedModelId: 'model',
  resolvedModelId: 'model',
);

String _sectionResponse(String tag) =>
    '<<<SUMMARY>>>\n- $tag summary\n'
    '<<<EXPLANATION>>>\n$tag explanation\n'
    '<<<DEEP_EXPLANATION>>>\n$tag deep\n';

void main() {
  late AppDatabase db;
  late _FakeClient client;
  late CourseReviewService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _FakeClient();
    service = CourseReviewService(
      db,
      client,
      PdfAiMaterialService(db, client, textSource: _FakeTextSource()),
      resolvePath: (m) async => '/tmp/${m.storedFileName}',
    );
    await _seed(db);
  });

  tearDown(() => db.close());

  Future<CourseReviewState> load() async =>
      (await service.repository.load('subject-1'))!;

  group('repository', () {
    test('lists every PDF in lesson order with not-added status', () async {
      final state = await load();
      expect(state.sources.map((s) => s.material.id), ['pdf-1', 'pdf-2']);
      expect(
        state.sources.map((s) => s.status),
        everyElement(CourseReviewSourceStatus.notAdded),
      );
      expect(state.isEmpty, isTrue);
    });

    test('exclusion and lesson-material changes update status', () async {
      var state = await load();
      client.outputs.add(_sectionResponse('L1'));
      await service.generateSection(
        source: state.sources.first,
        selection: _selection,
      );
      state = await load();
      expect(state.sources.first.status, CourseReviewSourceStatus.added);

      await _addLessonMaterial(db, 'pdf-1', 'summary', 'new lesson summary');
      state = await load();
      expect(state.sources.first.status, CourseReviewSourceStatus.outdated);

      await service.setExcluded(state.sources.last, true);
      state = await load();
      expect(state.sources.last.status, CourseReviewSourceStatus.excluded);
      expect(state.included.length, 1);
      await service.setExcluded(state.sources.last, false);
      expect((await load()).sources.last.excluded, isFalse);
    });
  });

  group('generation', () {
    test('uses existing lesson materials instead of the PDF text', () async {
      await _addLessonMaterial(db, 'pdf-1', 'summary', 'LESSON SUMMARY TEXT');
      final state = await load();
      client.outputs.add(_sectionResponse('L1'));
      await service.generateSection(
        source: state.sources.first,
        selection: _selection,
      );
      final input = client.messages.single.map((m) => m['content']).join();
      expect(input, contains('LESSON SUMMARY TEXT'));
      expect(input, isNot(contains('RAW PDF PAGE')));
      final saved = (await load()).sources.first.latest;
      expect(saved.keys, CourseReviewPart.sectionParts.toSet());
      expect(saved[CourseReviewPart.summary]!.content, '- L1 summary');
    });

    test('falls back to PDF text when no lesson materials exist', () async {
      final state = await load();
      client.outputs.add(_sectionResponse('L2'));
      await service.generateSection(
        source: state.sources.last,
        selection: _selection,
      );
      final input = client.messages.single.map((m) => m['content']).join();
      expect(input, contains('RAW PDF PAGE'));
    });

    test('an incomplete response saves nothing', () async {
      final state = await load();
      client.outputs.add('<<<SUMMARY>>>\nonly a summary');
      await expectLater(
        service.generateSection(
          source: state.sources.first,
          selection: _selection,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await db.courseReviewEntriesForSubject('subject-1'), isEmpty);
    });

    test('overview uses the compact sections and becomes outdated', () async {
      var state = await load();
      client.outputs.add(_sectionResponse('L1'));
      await service.generateSection(
        source: state.sources.first,
        selection: _selection,
      );
      state = await load();
      client.outputs.add(
        '<<<BIG_PICTURE>>>\nHow it fits\n<<<EXAMPLES>>>\n### Example 1: X',
      );
      await service.generateOverview(
        state: state,
        exampleCount: 7,
        selection: _selection,
      );
      final request = client.messages.last.last['content']!;
      expect(request, contains('Exactly 7 short'));
      expect(client.messages.last[1]['content'], contains('- L1 summary'));
      state = await load();
      expect(state.overview.keys, {
        CourseReviewPart.bigPicture,
        CourseReviewPart.examples,
      });
      expect(state.overviewOutdated, isFalse);

      client.outputs.add(_sectionResponse('L2'));
      await service.generateSection(
        source: state.sources.last,
        selection: _selection,
      );
      expect((await load()).overviewOutdated, isTrue);
    });

    test('regenerating appends a new version', () async {
      var state = await load();
      client.outputs.addAll([_sectionResponse('a'), _sectionResponse('b')]);
      await service.generateSection(
        source: state.sources.first,
        selection: _selection,
      );
      await service.generateSection(
        source: state.sources.first,
        selection: _selection,
      );
      state = await load();
      final summary = state.sources.first.latest[CourseReviewPart.summary]!;
      expect(summary.version, 2);
      expect(summary.content, '- b summary');
      expect(await db.courseReviewEntriesForSubject('subject-1'), hasLength(6));
    });
  });

  group('JSON import', () {
    late ManualEntryImportService importer;
    setUp(() => importer = ManualEntryImportService(db));

    ManualEntryBundle bundle(Map<String, dynamic> review) =>
        ManualEntryParser.parse(
          jsonEncode({
            'format': 'study-vault-manual-entry',
            'version': 1,
            'target': {'subject': 'Project Management'},
            'course_review': review,
          }),
        );

    const target = ManualEntryTarget(
      subjectId: 'subject-1',
      subjectName: 'Project Management',
    );

    test('parses sections, examples and big picture', () {
      final parsed = bundle({
        'sections': [
          {'lesson': 'Slide 2', 'pdf': 'Lect-02', 'summary': 'S'},
          {'lesson': 'Slide 3'},
        ],
        'examples': 'E',
        'big_picture': 'B',
      });
      expect(parsed.courseReview.sections, hasLength(1));
      expect(parsed.courseReview.itemCount, 3);
      expect(parsed.needsLesson, isFalse);
      expect(parsed.warnings.single, contains('section #2 is empty'));
    });

    test('matches PDFs loosely and needs no lesson', () async {
      final plan = await importer.buildPlan(
        bundle: bundle({
          'sections': [
            {'lesson': 'slide 2', 'pdf': 'Lect-02', 'summary': 'S2'},
            {'pdf': 'unknown', 'summary': 'S?'},
          ],
        }),
        target: target,
      );
      final items = plan.ofKind(ManualEntryKind.courseReview).toList();
      expect(items.first.targetMaterialId, 'pdf-1');
      expect(items.last.missingTarget, isTrue);
      expect(plan.unassignedSections, 1);
      expect(plan.missingLesson, isFalse);
      expect(plan.canSave, isTrue);
      expect(plan.reviewPdfs, hasLength(2));
    });

    test(
      'writes sections then current overview; assignment and replace',
      () async {
        final json = bundle({
          'sections': [
            {'lesson': 'Slide 2', 'pdf': 'Lect-02.pdf', 'summary': 'S2'},
            {'pdf': 'unknown', 'explanation': 'E3', 'deep_explanation': 'D3'},
          ],
          'examples': 'Examples',
        });
        var plan = await importer.buildPlan(
          bundle: json,
          target: target,
          reviewAssignments: {'cr:s:1': 'pdf-2'},
        );
        await importer.apply(plan);
        var state = await load();
        expect(state.sources.first.latest.keys, {CourseReviewPart.summary});
        expect(state.sources.last.latest.keys, {
          CourseReviewPart.explanation,
          CourseReviewPart.deepExplanation,
        });
        expect(state.sources.every((s) => s.status.name == 'added'), isTrue);
        expect(state.overviewOutdated, isFalse);

        plan = await importer.buildPlan(
          bundle: json,
          target: target,
          reviewAssignments: {'cr:s:1': 'pdf-2'},
        );
        final first = plan.items.first;
        expect(first.hasConflict, isTrue);
        first.resolution = ConflictResolution.replace;
        await importer.apply(plan);
        state = await load();
        final summary = state.sources.first.latest[CourseReviewPart.summary]!;
        expect(summary.version, 1);
        final explanation =
            state.sources.last.latest[CourseReviewPart.explanation]!;
        expect(explanation.version, 2);
      },
    );

    test('lesson items without a lesson block saving', () async {
      final parsed = ManualEntryParser.parse(
        jsonEncode({
          'flashcards': [
            {'front': 'Q', 'back': 'A'},
          ],
          'course_review': {'examples': 'E'},
        }),
      );
      final plan = await importer.buildPlan(bundle: parsed, target: target);
      expect(plan.missingLesson, isTrue);
      expect(plan.canSave, isFalse);
      await expectLater(importer.apply(plan), throwsStateError);
    });
  });

  group('complete document', () {
    test('saving the first complete document creates version 1', () async {
      final saved = await service.saveCompleteDocument(
        subjectId: 'subject-1',
        content: '  First complete review  ',
      );
      expect(saved.version, 1);
      expect(saved.part, CourseReviewPart.document.storageValue);
      expect(saved.materialId, isNull);
      expect(saved.content, 'First complete review');
      final state = await load();
      expect(state.document!.id, saved.id);
      expect(state.document!.version, 1);
      expect(state.documentOutdated, isFalse);
      expect(saved.sourceFingerprint, state.documentFingerprint);
    });

    test(
      'editing the complete document creates version 2 and keeps version 1',
      () async {
        await service.saveCompleteDocument(
          subjectId: 'subject-1',
          content: 'Version one',
        );
        final second = await service.saveCompleteDocument(
          subjectId: 'subject-1',
          content: 'Version two',
        );
        expect(second.version, 2);
        final documents =
            (await db.courseReviewEntriesForSubject(
                'subject-1',
              )).where((entry) => entry.part == 'document').toList()
              ..sort((a, b) => a.version.compareTo(b.version));
        expect(documents.map((entry) => entry.version), [1, 2]);
        expect(documents.map((entry) => entry.content), [
          'Version one',
          'Version two',
        ]);
        final state = await load();
        expect(state.document!.version, 2);
        expect(state.document!.content, 'Version two');
      },
    );

    test('repository loading returns the latest document', () async {
      await service.saveCompleteDocument(
        subjectId: 'subject-1',
        content: 'Older document',
      );
      await service.saveCompleteDocument(
        subjectId: 'subject-1',
        content: 'Latest document',
      );
      final state = await load();
      expect(state.document!.content, 'Latest document');
      expect(state.document!.version, 2);
      expect(state.document!.materialId, isNull);
    });

    test('an empty complete document is rejected', () async {
      await expectLater(
        service.saveCompleteDocument(subjectId: 'subject-1', content: ' \n '),
        throwsArgumentError,
      );
      expect(await db.courseReviewEntriesForSubject('subject-1'), isEmpty);
    });

    test(
      'changing or excluding a source marks the document outdated',
      () async {
        await service.saveCompleteDocument(
          subjectId: 'subject-1',
          content: 'Complete review',
        );
        var state = await load();
        expect(state.documentOutdated, isFalse);

        await service.setExcluded(state.sources.last, true);
        state = await load();
        expect(state.documentOutdated, isTrue);
        expect(state.document!.content, 'Complete review');
        expect(state.document!.version, 1);

        await service.setExcluded(state.sources.last, false);
        state = await load();
        expect(state.documentOutdated, isFalse);

        await _addLessonMaterial(
          db,
          'pdf-1',
          'summary',
          'edited lesson summary',
        );
        state = await load();
        expect(state.documentOutdated, isTrue);
        expect(state.document!.version, 1);
        expect(state.document!.content, 'Complete review');
      },
    );

    test('legacy sections compile in lesson order with the headings', () async {
      await db.insertCourseReviewVersion(
        id: 'pdf2-summary',
        subjectId: 'subject-1',
        materialId: 'pdf-2',
        part: 'summary',
        content: 'Schedule facts',
        sourceFingerprint: 'pdf:pdf-2:l2.pdf',
      );
      await db.insertCourseReviewVersion(
        id: 'pdf1-deep',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'deep_explanation',
        content: 'Core scope reasoning',
        sourceFingerprint: 'pdf:pdf-1:l1.pdf',
      );
      await db.insertCourseReviewVersion(
        id: 'pdf1-summary',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'summary',
        content: 'Scope of the project',
        sourceFingerprint: 'pdf:pdf-1:l1.pdf',
      );
      await db.insertCourseReviewVersion(
        id: 'pdf1-explanation',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'explanation',
        content: 'Why scope matters',
        sourceFingerprint: 'pdf:pdf-1:l1.pdf',
      );
      await db.insertCourseReviewVersion(
        id: 'big',
        subjectId: 'subject-1',
        materialId: null,
        part: 'big_picture',
        content: 'How the lectures fit',
        sourceFingerprint: 'sections:old',
      );
      await db.insertCourseReviewVersion(
        id: 'examples',
        subjectId: 'subject-1',
        materialId: null,
        part: 'examples',
        content: 'Worked course example',
        sourceFingerprint: 'sections:old',
      );
      final before = await db.courseReviewEntriesForSubject('subject-1');
      final markdown = service.compileLegacyDocument(await load());
      expect(markdown, '''
# Project Management Course Review

## Big Picture

How the lectures fit

## Slide 2 — Lect-02 .pdf

### Summary

Scope of the project

### Explanation

Why scope matters

### Deep Review

Core scope reasoning

## Slide 3 — Lect-03

### Summary

Schedule facts

## Course Examples

Worked course example''');
      expect(
        await db.courseReviewEntriesForSubject('subject-1'),
        hasLength(before.length),
      );
      expect((await load()).document, isNull);

      await service.setExcluded((await load()).sources.last, true);
      final excluded = service.compileLegacyDocument(await load());
      expect(excluded, isNot(contains('Slide 3')));
      expect(excluded, contains('## Slide 2 — Lect-02 .pdf'));
    });
  });

  testWidgets('screen shows one document and one complete-review edit action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData' && call.arguments is Map) {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final state = await tester.runAsync(() async {
      await service.saveCompleteDocument(
        subjectId: 'subject-1',
        content: 'The combined baseline covers every lecture.',
      );
      await db.insertCourseReviewVersion(
        id: 'legacy-summary',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'summary',
        content: 'Hidden legacy summary',
        sourceFingerprint: 'stale',
      );
      return load();
    });
    expect(state!.documentOutdated, isFalse);

    await _pumpReview(tester, db, state);
    expect(find.text('Course Review'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
    expect(find.text('Edit complete review'), findsOneWidget);
    expect(find.text('Create / paste complete review'), findsNothing);
    expect(
      find.textContaining('combined baseline covers every lecture'),
      findsOneWidget,
    );
    expect(find.textContaining('Hidden legacy summary'), findsNothing);
    expect(find.text('Lect-02 .pdf'), findsOneWidget);
    expect(find.text('Lect-03'), findsOneWidget);
    expect(find.text('Exclude'), findsNWidgets(2));
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.text('Edit summary'), findsNothing);
    expect(find.text('Edit explanation'), findsNothing);
    expect(find.text('Edit deep'), findsNothing);
    expect(find.text('Generate missing (2)'), findsNothing);
    expect(find.text('Generate section'), findsNothing);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Explanation'), findsNothing);
    expect(find.text('Examples'), findsNothing);

    await tester.tap(find.text('Copy prompt for complete review'));
    await tester.pump();
    expect(copied, isNotNull);
    expect(copied, contains('one Markdown document'));
    expect(copied, contains('Do not return JSON'));
    expect(copied, contains('Project Management'));
    expect(copied, contains('already studied'));
    expect(copied, contains('Lesson: "Slide 2", PDF: "Lect-02 .pdf"'));
    expect(copied, contains('Lesson: "Slide 3", PDF: "Lect-03"'));
    expect(copied, contains('## Slide 2 — Lect-02 .pdf'));
    expect(copied, contains('### Summary'));
    expect(copied, contains('### Explanation'));
    expect(copied, contains('### Deep Review'));
    expect(copied, contains('## Big Picture'));
    expect(copied, contains('## Course Examples'));
    expect(copied, contains('Preserve formulas'));
    expect(copied, contains('Do not invent'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an outdated document shows a warning without rewriting it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await tester.runAsync(() async {
      await db.insertCourseReviewVersion(
        id: 'doc-1',
        subjectId: 'subject-1',
        materialId: null,
        part: 'document',
        content: 'Saved before the lectures changed.',
        sourceFingerprint: 'documents:stale',
      );
      return load();
    });
    expect(state!.documentOutdated, isTrue);
    await _pumpReview(tester, db, state);
    expect(find.textContaining('Outdated'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
    expect(
      find.textContaining('Saved before the lectures changed.'),
      findsOneWidget,
    );
    expect(find.text('Edit complete review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy sections offer combine and hide per-section editors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await tester.runAsync(() async {
      await db.insertCourseReviewVersion(
        id: 'legacy-summary',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'summary',
        content: 'Hidden legacy summary',
        sourceFingerprint: 'pdf:pdf-1:l1.pdf',
      );
      return load();
    });
    await _pumpReview(tester, db, state);
    expect(find.text('Create / paste complete review'), findsOneWidget);
    expect(find.text('Combine existing review'), findsOneWidget);
    expect(find.text('Edit complete review'), findsNothing);
    expect(find.textContaining('Hidden legacy summary'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Edit summary'), findsNothing);

    tester.view.physicalSize = const Size(1400, 1600);
    await tester.pump();
    await tester.tap(find.text('Create / paste complete review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Create complete review'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('A complete review cannot be empty.'),
      findsAtLeastNWidgets(1),
    );
    final rows = await tester.runAsync(
      () => db.courseReviewEntriesForSubject('subject-1'),
    );
    expect(rows!.where((entry) => entry.part == 'document'), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the copied prompt omits excluded lessons', () async {
    await service.setExcluded((await load()).sources.last, true);
    final prompt = CourseReviewPrompts.completeReviewPrompt(await load());
    expect(prompt, contains('one Markdown document'));
    expect(prompt, contains('Do not return JSON'));
    expect(prompt, contains('Lesson: "Slide 2", PDF: "Lect-02 .pdf"'));
    expect(prompt, isNot(contains('Slide 3')));
    expect(prompt, isNot(contains('Lect-03')));
  });

  group('prompts', () {
    test('parser tolerates text around markers but needs every part', () {
      final parts = CourseReviewPrompts.parse(
        'Sure!\n<<<SUMMARY>>>\nA\n<<<EXPLANATION>>>\nB\n<<<DEEP_EXPLANATION>>>\nC',
        CourseReviewPart.sectionParts,
      );
      expect(parts.values, ['A', 'B', 'C']);
    });

    test('the bundled instruction has a Course Review block', () {
      final markdown = File('manual_entry_instruction.md').readAsStringSync();
      final prompt = courseReviewPromptFromInstruction(markdown);
      expect(prompt, startsWith('You are building the COURSE REVIEW'));
      expect(prompt, contains('"course_review"'));
      expect(prompt, isNot(contains('```')));
      expect(
        manualEntryPromptFromInstruction(markdown),
        startsWith('You are helping me'),
      );
    });
  });
}

Future<void> _pumpReview(
  WidgetTester tester,
  AppDatabase db,
  CourseReviewState? state,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        courseReviewProvider(
          'subject-1',
        ).overrideWith((ref) => Stream.value(state)),
        materialBookLinksProvider.overrideWith(
          (ref, id) => Stream.value(const []),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: CourseReviewScreen(subjectId: 'subject-1'),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime(2026);
  await db.insertClass(
    ClassesCompanion.insert(
      id: 'class-1',
      name: 'MCS-1',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertSubject(
    SubjectsCompanion.insert(
      id: 'subject-1',
      classId: 'class-1',
      name: 'Project Management',
      createdAt: now,
      updatedAt: now,
    ),
  );
  for (final (i, name) in [(1, 'Slide 2'), (2, 'Slide 3')].indexed) {
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'lesson-${name.$1}',
        subjectId: 'subject-1',
        name: name.$2,
        sortOrder: Value(i),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'pdf-${name.$1}',
        lessonId: 'lesson-${name.$1}',
        title: name.$1 == 1 ? 'Lect-02 .pdf' : 'Lect-03',
        originalFileName: 'l${name.$1}.pdf',
        storedFileName: 'l${name.$1}.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

Future<void> _addLessonMaterial(
  AppDatabase db,
  String materialId,
  String type,
  String content,
) {
  return db.insertPdfAiMaterialVersion(
    materialId: materialId,
    type: type,
    builder: (version) => PdfAiMaterialsCompanion.insert(
      id: '$materialId-$type-$version',
      materialId: materialId,
      type: type,
      content: content,
      version: version,
      generatedAt: DateTime(2026),
      sourceFingerprint: 'fp',
    ),
  );
}

class _FakeTextSource implements PdfDocumentTextSource {
  @override
  Future<List<SourcePageText>> extractAllPages(String filePath) async => const [
    SourcePageText(pageNumber: 1, text: 'RAW PDF PAGE'),
  ];
}

class _FakeClient implements PdfAiCompletionClient {
  final outputs = <String>[];
  final messages = <List<Map<String, String>>>[];

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) async {
    this.messages.add(messages);
    return PdfAiCompletion(
      markdown: outputs.removeAt(0),
      provider: 'deepseek',
      model: 'model',
    );
  }
}
