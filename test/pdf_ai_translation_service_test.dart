import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_translation.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_translation_service.dart';

import 'helpers/ai_selection_helpers.dart';

/// Pretends to translate by prefixing each non-placeholder line with "FA:".
class _Translator implements PdfAiCompletionClient {
  final prompts = <String>[];
  String Function(String text)? rewrite;

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) async {
    final prompt = messages.last['content']!;
    prompts.add(prompt);
    final text = prompt.substring(prompt.indexOf('MARKDOWN:\n') + 10);
    final translated =
        rewrite?.call(text) ??
        [
          for (final line in text.split('\n'))
            line.trim().isEmpty || line.contains('⟦SV')
                ? line
                : line.startsWith('#')
                ? line.replaceFirstMapped(
                    RegExp(r'^(#+ )'),
                    (m) => '${m[1]}FA:',
                  )
                : 'FA:$line',
        ].join('\n');
    return PdfAiCompletion(
      markdown: translated,
      provider: 'deepseek',
      model: 'test',
    );
  }
}

void main() {
  late AppDatabase db;
  late _Translator client;
  late PdfAiTranslationService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Translator();
    service = PdfAiTranslationService(db, client);
    final t = DateTime(2026);
    await db.insertClass(
      ClassesCompanion.insert(id: 'c', name: 'C', createdAt: t, updatedAt: t),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's',
        classId: 'c',
        name: 'S',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l',
        subjectId: 's',
        name: 'L',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'm',
        lessonId: 'l',
        title: 'Cells',
        originalFileName: 'a.pdf',
        storedFileName: 'a.pdf',
        createdAt: t,
        updatedAt: t,
      ),
    );
  });
  tearDown(() => db.close());

  Future<PdfAiMaterial> source(String content) => db.insertPdfAiMaterialVersion(
    materialId: 'm',
    type: 'summary',
    builder: (version) => PdfAiMaterialsCompanion.insert(
      id: 'v$version',
      materialId: 'm',
      type: 'summary',
      content: content,
      version: version,
      generatedAt: DateTime(2026),
      sourceFingerprint: 'f',
    ),
  );

  test('translates every section and keeps code untouched', () async {
    final long = 'Sentence about cells. ' * 200;
    final original = await source(
      '# Cells\n$long\n\n```python\nprint("x")\n```\n\n## Mitosis\n$long',
    );
    final progress = <String>[];
    final saved = await service.translate(
      source: original,
      selection: testDeepSeekSelection(),
      onProgress: (done, total) => progress.add('$done/$total'),
    );
    final segments = PdfAiTranslation.split(saved.content);
    expect(
      segments,
      hasLength(PdfAiTranslation.segments(original.content).length),
    );
    expect(segments.length, greaterThan(1));
    expect(progress.first, '0/${segments.length}');
    expect(progress.last, '${segments.length}/${segments.length}');
    expect(saved.content, contains('# FA:Cells'));
    expect(saved.content, contains('print("x")'));
    expect(client.prompts.join(), isNot(contains('print("x")')));
    expect(saved.language, 'fa');
    expect(PdfAiTranslationService.isStale(saved, original), isFalse);

    final map = await service.watchForMaterial('m').first;
    expect(map[original.id]!.id, saved.id);
  });

  test('retranslating replaces the row and edits mark it stale', () async {
    final original = await source('# A\nText');
    final first = await service.translate(
      source: original,
      selection: testDeepSeekSelection(),
    );
    final edited = await db.updatePdfAiMaterialContent(
      id: original.id,
      content: '# A\nChanged',
    );
    expect(PdfAiTranslationService.isStale(first, edited), isTrue);
    final second = await service.translate(
      source: edited,
      selection: testDeepSeekSelection(),
    );
    expect(second.id, first.id);
    expect(second.content, contains('FA:Changed'));
    expect(await db.select(db.pdfAiMaterialTranslations).get(), hasLength(1));

    await db.deletePdfAiMaterial(original.id);
    expect(await db.select(db.pdfAiMaterialTranslations).get(), isEmpty);
  });

  test('a lost code block is retried, then fails without saving', () async {
    final original = await source('# A\n```\ncode\n```\nText');
    client.rewrite = (text) => text.replaceAll('⟦SV0⟧', '');
    await expectLater(
      service.translate(source: original, selection: testDeepSeekSelection()),
      throwsStateError,
    );
    expect(client.prompts, hasLength(2));
    expect(client.prompts.last, contains('previous answer changed'));
    expect(await db.select(db.pdfAiMaterialTranslations).get(), isEmpty);
    expect(service.isTranslating(original.id), isFalse);
  });
}
