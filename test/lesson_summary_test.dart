import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/services/quill_to_markdown.dart';
import 'package:study_vault/features/lessons/data/lesson_summary_repository.dart';
import 'package:study_vault/features/lessons/domain/lesson_summary.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';

void main() {
  group('LessonSummaryInput.parse', () {
    test('keeps plain text and Markdown as-is', () {
      expect(
        LessonSummaryInput.parse('  # Topic\n\n- point  '),
        '# Topic\n\n- point',
      );
      expect(
        LessonSummaryInput.parse('[link](x) is text'),
        '[link](x) is text',
      );
    });

    test('reads the study-vault AI JSON and fenced JSON', () {
      const json =
          '{"format":"study-vault-pdf-ai","type":"summary","content":"# A\\n\\nB"}';
      expect(LessonSummaryInput.parse(json), '# A\n\nB');
      expect(LessonSummaryInput.parse('```json\n$json\n```'), '# A\n\nB');
    });

    test('reads titled sections and lists', () {
      const json =
          '{"sections":[{"title":"One","content":"first"},"second",'
          '{"summary":"third"}]}';
      expect(
        LessonSummaryInput.parse(json),
        '## One\n\nfirst\n\nsecond\n\nthird',
      );
    });

    test('rejects empty input and JSON without text', () {
      expect(() => LessonSummaryInput.parse('   '), throwsFormatException);
      expect(() => LessonSummaryInput.parse('{"x":1}'), throwsFormatException);
    });
  });

  test('append adds a heading after existing content', () {
    final first = LessonSummary.append(null, 'Alpha');
    final both = LessonSummary.append(first, 'Beta', heading: 'PDF 2');
    final markdown = QuillToMarkdown.fromStored(both);
    expect(markdown, contains('Alpha'));
    expect(markdown, contains('## PDF 2'));
    expect(markdown.indexOf('Alpha'), lessThan(markdown.indexOf('Beta')));
  });

  test('summary id is stable per lesson', () {
    expect(
      LessonSummary.noteIdFor('lesson-1'),
      LessonSummary.noteIdFor('lesson-1'),
    );
    expect(
      LessonSummary.noteIdFor('lesson-1'),
      isNot(LessonSummary.noteIdFor('lesson-2')),
    );
  });

  group('LessonSummaryRepository', () {
    late AppDatabase db;
    late LessonSummaryRepository repository;
    late PdfAiMaterialService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(db);
      repository = LessonSummaryRepository(db);
      service = PdfAiMaterialService(db, _NoAiClient());
    });

    tearDown(() => db.close());

    Future<String> summaryMarkdown() async {
      final note = await db.getStudyNoteById(
        LessonSummary.noteIdFor('lesson-1'),
      );
      return QuillToMarkdown.fromStored(note!.content);
    }

    test('first use collects the latest summary of every PDF', () async {
      await db.insertPdfAiMaterialVersion(
        materialId: 'pdf-1',
        type: 'summary',
        builder: (version) => PdfAiMaterialsCompanion.insert(
          id: 'old',
          materialId: 'pdf-1',
          type: 'summary',
          content: 'First PDF summary',
          version: version,
          generatedAt: DateTime(2026),
          sourceFingerprint: 'f',
        ),
      );
      final note = await repository.ensure('lesson-1');
      expect(note.lessonId, 'lesson-1');
      expect(await summaryMarkdown(), contains('First PDF summary'));
      expect(await summaryMarkdown(), contains('## PDF One'));
    });

    test('new AI summaries append without duplicating', () async {
      await service.importManual(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
        content: 'Summary one',
      );
      await service.importManual(
        materialId: 'pdf-2',
        type: PdfAiMaterialType.summary,
        content: 'Summary two',
      );
      await service.importManual(
        materialId: 'pdf-2',
        type: PdfAiMaterialType.explanation,
        content: 'Not a summary',
      );
      final markdown = await summaryMarkdown();
      expect('Summary one'.allMatches(markdown), hasLength(1));
      expect(markdown, contains('## PDF Two'));
      expect(markdown, contains('Summary two'));
      expect(markdown, isNot(contains('Not a summary')));
    });

    test('pasted text appends and clear empties it', () async {
      await repository.appendMarkdown(lessonId: 'lesson-1', markdown: 'Mine');
      expect(await summaryMarkdown(), contains('Mine'));
      await repository.clear('lesson-1');
      expect((await summaryMarkdown()).trim(), isEmpty);
      final pdfSummaries = await db.listPdfAiMaterials(
        materialId: 'pdf-1',
        type: 'summary',
      );
      expect(pdfSummaries, isEmpty);
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
  for (final (index, title) in ['PDF One', 'PDF Two'].indexed) {
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'pdf-${index + 1}',
        lessonId: 'lesson-1',
        title: title,
        originalFileName: '$title.pdf',
        storedFileName: '$title.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _NoAiClient implements PdfAiCompletionClient {
  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) => throw UnimplementedError();
}
