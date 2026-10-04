import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_questions/domain/quiz_models.dart';
import 'package:study_vault/features/manual_entry/data/manual_entry_providers.dart';
import 'package:study_vault/features/manual_entry/domain/manual_entry_models.dart';
import 'package:study_vault/features/manual_entry/domain/manual_entry_plan.dart';
import 'package:study_vault/features/manual_entry/services/manual_entry_import_service.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';

const _fullBundle = {
  'format': 'study-vault-manual-entry',
  'version': 1,
  'target': {
    'class': 'Class',
    'subject': ' subject ',
    'lesson': 'LESSON',
    'pdf': 'PDF',
  },
  'study_materials': {
    'summary': '# Gradient descent\n- step along negative gradient',
    'deep_explanation': 'Deep text',
    'bogus': 'ignored',
  },
  'notes': [
    {'title': 'Key terms', 'content': '**Learning rate** controls step size.'},
    {'content': '# Untitled heading\nbody'},
    {'title': 'No content'},
  ],
  'annotations': [
    {
      'page': 2,
      'short_text': 'Learning rate',
      'full_note': 'Step size',
      'category': 'definition',
    },
    {'page': 2, 'short_text': 'Second pin'},
    {'short_text': 'missing page'},
    {'page': 3, 'short_text': 'Odd category', 'category': 'weird'},
  ],
  'flashcards': [
    {'front': 'What is α?', 'back': 'The learning rate.'},
    {'front': 'Broken'},
  ],
  'quizzes': [
    {
      'title': 'Week 3 quiz',
      'difficulty': 'hard',
      'questions': [
        {
          'type': 'mcq',
          'question': 'Pick',
          'options': ['a', 'b', 'c', 'd'],
          'correct': 'C',
          'explanation': 'because',
        },
        {
          'type': 'true_false',
          'question': 'GD is iterative',
          'correct': 'true',
        },
        {'type': 'short_answer', 'question': 'Name it', 'answer': 'gradient'},
        {
          'type': 'mcq',
          'question': 'Bad',
          'options': ['a', 'b'],
          'correct': 0,
        },
      ],
    },
    {'title': 'Empty', 'questions': []},
  ],
};

void main() {
  group('ManualEntryParser', () {
    test('parses every section leniently and reports skipped items', () {
      final bundle = ManualEntryParser.parse(
        '```json\n${jsonEncode(_fullBundle)}\n```',
      );

      expect(bundle.target.subjectName, 'subject');
      expect(bundle.target.pdfTitle, 'PDF');
      expect(bundle.studyMaterials.map((m) => m.type), [
        PdfAiMaterialType.summary,
        PdfAiMaterialType.deepExplanation,
      ]);
      expect(bundle.notes.map((n) => n.title), [
        'Key terms',
        'Untitled heading',
      ]);
      expect(bundle.annotations.length, 3);
      expect(bundle.annotations.first.categoryKey, 'definition');
      expect(bundle.annotations.last.categoryKey, isNull);
      expect(bundle.flashcards.single.front, 'What is α?');
      expect(bundle.quizzes.single.questions.length, 3);
      expect(bundle.quizzes.single.questions.first.correctAnswer, 2);
      expect(bundle.quizzes.single.questions[1].correctAnswer, true);
      expect(bundle.quizzes.single.questionType, QuizQuestionType.mixed);
      expect(bundle.quizzes.single.difficulty, QuizDifficulty.hard);
      expect(bundle.needsPdf, isTrue);
      expect(bundle.warnings, hasLength(7));
      expect(bundle.warnings.join('\n'), contains('bogus'));
      expect(bundle.warnings.join('\n'), contains('exactly 4'));
    });

    test('rejects non-JSON and non-object roots', () {
      expect(
        () => ManualEntryParser.parse('hello'),
        throwsA(isA<ManualEntryFormatException>()),
      );
      expect(
        () => ManualEntryParser.parse('[1,2]'),
        throwsA(isA<ManualEntryFormatException>()),
      );
      expect(
        () => ManualEntryParser.parse('   '),
        throwsA(isA<ManualEntryFormatException>()),
      );
    });

    test('partial bundle without PDF-bound content does not need a PDF', () {
      final bundle = ManualEntryParser.parse(
        jsonEncode({
          'flashcards': [
            {'front': 'Q', 'back': 'A'},
          ],
        }),
      );
      expect(bundle.needsPdf, isFalse);
      expect(bundle.itemCount, 1);
      expect(bundle.warnings, isEmpty);
    });
  });

  test('instruction file yields a self-contained AI prompt', () {
    final markdown = File('manual_entry_instruction.md').readAsStringSync();
    final prompt = manualEntryPromptFromInstruction(markdown);
    expect(prompt, startsWith('You are helping me'));
    expect(prompt, contains('"format": "study-vault-manual-entry"'));
    expect(prompt, isNot(contains('## ')));
    expect(prompt, isNot(contains('```')));
    for (final key in [
      'study_materials',
      'notes',
      'annotations',
      'flashcards',
      'quizzes',
    ]) {
      expect(prompt, contains('"$key"'));
    }
  });

  group('ManualEntryImportService', () {
    late AppDatabase db;
    late ManualEntryImportService service;
    const target = ManualEntryTarget(
      lessonId: 'lesson-1',
      lessonName: 'Lesson',
      subjectId: 'subject-1',
      materialId: 'pdf-1',
      materialTitle: 'PDF',
    );

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(db);
      service = ManualEntryImportService(db);
    });

    tearDown(() => db.close());

    test(
      'plan flags conflicts and apply writes everything atomically',
      () async {
        final bundle = ManualEntryParser.parse(jsonEncode(_fullBundle));
        final plan = await service.buildPlan(bundle: bundle, target: target);

        expect(plan.before.notes, 1);
        expect(plan.items.where((i) => i.hasConflict).map((i) => i.id), [
          'note:0',
        ]);
        expect(plan.after.notes, 3);
        expect(plan.missingPdf, isFalse);

        final noteItem = plan.items.firstWhere((i) => i.id == 'note:0');
        noteItem.resolution = ConflictResolution.replace;
        plan.items.firstWhere((i) => i.id == 'pin:1').included = false;
        expect(plan.after.notes, 2);

        final result = await service.apply(plan);
        expect(result.added, plan.items.length - 2);
        expect(result.replaced, 1);
        expect(result.skipped, 1);

        final notes = await db.getStudyNotesForLesson('lesson-1');
        expect(notes.map((n) => n.title).toSet(), {
          'Key terms',
          'Untitled heading',
        });
        expect(
          notes.firstWhere((n) => n.title == 'Key terms').plainTextContent,
          contains('Learning rate'),
        );

        final pins = await db.getStudyPinsForResource('pdf-1');
        expect(pins.length, 2);
        final definition = pins.firstWhere(
          (p) => p.shortText == 'Learning rate',
        );
        expect(definition.categoryId, 'cat_definition');
        expect(definition.pageNumber, 2);
        expect(definition.fullExplanationPlainText, 'Step size');

        final materials = await db.watchPdfAiMaterials('pdf-1').first;
        expect(materials.map((m) => m.type).toSet(), {
          'summary',
          'deep_explanation',
        });
        expect(materials.every((m) => m.provider == 'manual'), isTrue);

        final cards = await db.watchFlashcardsForLesson('lesson-1').first;
        expect(cards.single.backPlainText, 'The learning rate.');
        expect(cards.single.subjectId, 'subject-1');

        final sets = await db.watchQuestionSetsForLesson('lesson-1').first;
        expect(sets.single.questionCount, 3);
        final questions = await db.getQuizQuestionsForSet(sets.single.id);
        final options = await db.getOptionsForQuestion(questions.first.id);
        expect(options.where((o) => o.isCorrect).single.optionText, 'c');
        final tf = await db.getOptionsForQuestion(questions[1].id);
        expect(tf.firstWhere((o) => o.optionText == 'True').isCorrect, isTrue);
      },
    );

    test(
      'study material conflict resolutions version or replace latest',
      () async {
        final bundle = ManualEntryParser.parse(
          jsonEncode({
            'study_materials': {'summary': 'first'},
          }),
        );
        await service.apply(
          await service.buildPlan(bundle: bundle, target: target),
        );

        final second = ManualEntryParser.parse(
          jsonEncode({
            'study_materials': {'summary': 'second'},
          }),
        );
        var plan = await service.buildPlan(bundle: second, target: target);
        expect(plan.items.single.existing?.description, contains('v1'));
        await service.apply(plan);
        var versions = await db.listPdfAiMaterials(
          materialId: 'pdf-1',
          type: 'summary',
        );
        expect(versions.map((v) => v.version), [2, 1]);

        final third = ManualEntryParser.parse(
          jsonEncode({
            'study_materials': {'summary': 'third'},
          }),
        );
        plan = await service.buildPlan(bundle: third, target: target);
        expect(plan.items.single.existing?.description, contains('v2'));
        plan.items.single.resolution = ConflictResolution.replace;
        final result = await service.apply(plan);
        expect(result.replaced, 1);
        versions = await db.listPdfAiMaterials(
          materialId: 'pdf-1',
          type: 'summary',
        );
        // Replace keeps older history: v2 is swapped, v1 untouched.
        expect(versions.map((v) => v.version), [2, 1]);
        expect(versions.map((v) => v.content), ['third', 'first']);
      },
    );

    test('apply refuses PDF-bound items without a PDF', () async {
      final bundle = ManualEntryParser.parse(
        jsonEncode({
          'study_materials': {'summary': 'text'},
          'flashcards': [
            {'front': 'Q', 'back': 'A'},
          ],
        }),
      );
      const noPdf = ManualEntryTarget(
        lessonId: 'lesson-1',
        lessonName: 'Lesson',
        subjectId: 'subject-1',
      );
      final plan = await service.buildPlan(bundle: bundle, target: noPdf);
      expect(plan.missingPdf, isTrue);
      await expectLater(service.apply(plan), throwsStateError);
      expect(await db.watchFlashcardsForLesson('lesson-1').first, isEmpty);

      plan.items
              .firstWhere((i) => i.kind == ManualEntryKind.studyMaterial)
              .included =
          false;
      expect(plan.missingPdf, isFalse);
      await service.apply(plan);
      expect(await db.watchFlashcardsForLesson('lesson-1').first, hasLength(1));
    });

    test('rebuilding a plan keeps earlier decisions', () async {
      final bundle = ManualEntryParser.parse(jsonEncode(_fullBundle));
      final first = await service.buildPlan(bundle: bundle, target: target);
      first.items.firstWhere((i) => i.id == 'card:0').included = false;
      first.items.firstWhere((i) => i.id == 'note:0').resolution =
          ConflictResolution.skip;

      final again = await service.buildPlan(
        bundle: bundle,
        target: target,
        previous: first,
      );
      expect(again.items.firstWhere((i) => i.id == 'card:0').included, isFalse);
      expect(
        again.items.firstWhere((i) => i.id == 'note:0').resolution,
        ConflictResolution.skip,
      );
    });
  });
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime(2026);
  await db.insertClass(
    ClassesCompanion.insert(
      id: 'class-1',
      name: 'Class',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertSubject(
    SubjectsCompanion.insert(
      id: 'subject-1',
      classId: 'class-1',
      name: 'Subject',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLesson(
    LessonsCompanion.insert(
      id: 'lesson-1',
      subjectId: 'subject-1',
      name: 'Lesson',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLessonMaterial(
    LessonMaterialsCompanion.insert(
      id: 'pdf-1',
      lessonId: 'lesson-1',
      title: 'PDF',
      originalFileName: 'pdf.pdf',
      storedFileName: 'pdf.pdf',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertStudyNote(
    StudyNotesCompanion.insert(
      id: 'note-1',
      lessonId: const Value('lesson-1'),
      title: 'key terms',
      content: '[{"insert":"old\\n"}]',
      createdAt: now,
      updatedAt: now,
    ),
  );
}
