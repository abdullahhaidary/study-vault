import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  testWidgets('screen shows lecture status and the combined summary', (
    tester,
  ) async {
    final state = await tester.runAsync(() async {
      await db.insertCourseReviewVersion(
        id: 'e1',
        subjectId: 'subject-1',
        materialId: 'pdf-1',
        part: 'summary',
        content: '- **Scope** baseline',
        sourceFingerprint: 'pdf:pdf-1:l1.pdf',
      );
      return load();
    });
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
          home: CourseReviewScreen(subjectId: 'subject-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Course Review'), findsOneWidget);
    expect(find.textContaining('Scope'), findsOneWidget);
    expect(find.text('Lect-02 .pdf'), findsOneWidget);

    await tester.tap(find.text('Lectures'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 lectures added'), findsOneWidget);
    expect(find.text('Generate missing (1)'), findsOneWidget);
    expect(find.textContaining('Not added yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
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
  }) async {
    this.messages.add(messages);
    return PdfAiCompletion(
      markdown: outputs.removeAt(0),
      provider: 'deepseek',
      model: 'model',
    );
  }
}
