import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ai_selection_helpers.dart';
import 'package:study_vault/core/backup/backup_providers.dart';
import 'package:study_vault/core/backup/backup_service.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/annotation_ai_context.dart';
import 'package:study_vault/features/ai_assistant/domain/annotation_ai_history.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_history_service.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';

void main() {
  late AppDatabase db;
  late FakeAiService fakeAi;
  late AnnotationAiHistoryService history;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeAi = FakeAiService();
    history = AnnotationAiHistoryService(
      db: db,
      aiService: AnnotationAiService(aiService: fakeAi),
    );

    final now = DateTime(2026);
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's',
        classId: 'c',
        name: 'Subject',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l',
        subjectId: 's',
        name: 'Lesson',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'mat-1',
        lessonId: 'l',
        title: 'Material',
        originalFileName: 'a.pdf',
        storedFileName: 'a.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'ann-84',
        resourceId: 'mat-1',
        pinType: const Value('point'),
        pageNumber: const Value(18),
        xRatio: 0.5,
        yRatio: 0.5,
        shortText: 'GD',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: 'ann-99',
        resourceId: 'mat-1',
        pinType: const Value('point'),
        pageNumber: const Value(20),
        xRatio: 0.4,
        yRatio: 0.4,
        shortText: 'BP',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => db.close());

  const contextA = AnnotationAiContext(
    selectedText: 'Gradient descent is an optimization algorithm.',
    annotationId: 'ann-84',
    materialId: 'mat-1',
    pageNumber: 18,
  );

  const contextB = AnnotationAiContext(
    selectedText: 'Different annotation text about backpropagation.',
    annotationId: 'ann-99',
    materialId: 'mat-1',
    pageNumber: 20,
  );

  test('schema version is 16 and matches backup constants', () {
    expect(db.schemaVersion, 17);
    expect(kStudyVaultSchemaVersion, 17);
    expect(BackupService().currentSchemaVersion, 17);
  });

  test('source fingerprints prefer annotation id and separate selections', () {
    final a = AnnotationAiSourceFingerprint.fromContext(contextA);
    final b = AnnotationAiSourceFingerprint.fromContext(contextB);
    expect(a, 'ann:ann-84');
    expect(b, 'ann:ann-99');
    expect(a, isNot(b));

    final sel = AnnotationAiSourceFingerprint.from(
      materialId: 'mat-1',
      pageNumber: 3,
      inputText: 'selected text',
    );
    expect(sel, startsWith('sel:mat-1:3:'));
  });

  test('first generation is V1 and second is V2 without overwrite', () async {
    final v1 = await history.generate(
      context: contextA,
      action: AiStudyAction.summarize,
      selection: testGeminiSelection(),
      summarizeMode: AiSummarizeMode.oneParagraph,
    );
    final v2 = await history.generate(
      context: contextA,
      action: AiStudyAction.summarize,
      selection: testGeminiSelection(),
      summarizeMode: AiSummarizeMode.bulletPoints,
    );

    expect(v1.generationNumber, 1);
    expect(v2.generationNumber, 2);
    expect(v1.responseText, isNotEmpty);
    expect(v2.responseText, isNotEmpty);
    expect(v1.totalTokens, 120);
    expect(v1.promptTokens, 100);
    expect(v1.completionTokens, 20);
    expect(v2.totalTokens, 120);

    final listed = await history.getGenerations(
      sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
      action: AiStudyAction.summarize,
    );
    expect(listed, hasLength(2));
    expect(listed.first.responseText, v1.responseText);
    expect(listed.last.responseText, v2.responseText);
  });

  test(
    'manual editing keeps original and links a persisted new version',
    () async {
      final original = await history.persistCompleted(
        context: contextA,
        action: AiStudyAction.explain,
        responseText: 'AI answer',
      );
      final edited = await history.editGeneration(
        original: original,
        responseText: '  Corrected answer  ',
      );
      final versions = await history.getGenerations(
        sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
        action: AiStudyAction.explain,
      );

      expect(versions.map((g) => g.responseText), [
        'AI answer',
        'Corrected answer',
      ]);
      expect(edited.generationNumber, 2);
      expect(edited.parentGenerationId, original.id);
      expect(edited.totalTokens, isNull);
    },
  );

  test('regenerate of older version creates a new version', () async {
    final v1 = await history.generate(
      context: contextA,
      action: AiStudyAction.explain,
      selection: testGeminiSelection(),
    );
    final v2 = await history.generate(
      context: contextA,
      action: AiStudyAction.explain,
      selection: testGeminiSelection(),
    );
    final v3 = await history.regenerate(
      context: contextA,
      action: AiStudyAction.explain,
      selection: testGeminiSelection(),
      parent: v1,
      regenerateInstruction: 'Make it shorter',
    );

    expect(v3.generationNumber, 3);
    expect(v3.parentGenerationId, v1.id);
    expect(v3.customPrompt, contains('Make it shorter'));

    final listed = await history.getGenerations(
      sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
      action: AiStudyAction.explain,
    );
    expect(listed, hasLength(3));
    expect(listed[0].responseText, v1.responseText);
    expect(listed[1].responseText, v2.responseText);
  });

  test('generation counts are per action and annotation', () async {
    await history.generate(
      context: contextA,
      action: AiStudyAction.summarize,
      selection: testGeminiSelection(),
    );
    await history.generate(
      context: contextA,
      selection: testGeminiSelection(),
      action: AiStudyAction.summarize,
    );
    await history.generate(
      context: contextA,
      action: AiStudyAction.explain,
      selection: testGeminiSelection(),
    );
    await history.generate(
      context: contextB,
      selection: testGeminiSelection(),
      action: AiStudyAction.summarize,
    );

    final countsA = await history.getGenerationCounts(
      sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
    );
    final countsB = await history.getGenerationCounts(
      sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextB),
    );

    expect(countsA[AiStudyAction.summarize], 2);
    expect(countsA[AiStudyAction.explain], 1);
    expect(countsB[AiStudyAction.summarize], 1);
    expect(countsA[AiStudyAction.simplify], isNull);
  });

  test(
    'delete selected generation keeps others; Gemini failure preserves history',
    () async {
      final v1 = await history.generate(
        context: contextA,
        action: AiStudyAction.simplify,
        selection: testGeminiSelection(),
      );
      final v2 = await history.generate(
        context: contextA,
        action: AiStudyAction.simplify,
        selection: testGeminiSelection(),
      );
      final v3 = await history.generate(
        context: contextA,
        action: AiStudyAction.simplify,
        selection: testGeminiSelection(),
      );

      await history.deleteGeneration(v3.id);
      var listed = await history.getGenerations(
        sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
        action: AiStudyAction.simplify,
      );
      expect(listed.map((g) => g.id), [v1.id, v2.id]);

      fakeAi.handler = (_) async {
        throw const AiServerException('Simulated Gemini failure');
      };
      await expectLater(
        () => history.generate(
          context: contextA,
          action: AiStudyAction.simplify,
          selection: testGeminiSelection(),
        ),
        throwsA(isA<AiException>()),
      );
      listed = await history.getGenerations(
        sourceFingerprint: AnnotationAiSourceFingerprint.fromContext(contextA),
        action: AiStudyAction.simplify,
      );
      expect(listed, hasLength(2));
    },
  );

  test('source metadata and prompt version are preserved', () async {
    final gen = await history.generate(
      context: contextA,
      action: AiStudyAction.define,
      selection: testGeminiSelection(),
    );
    expect(gen.annotationId, 'ann-84');
    expect(gen.materialId, 'mat-1');
    expect(gen.pageNumber, 18);
    expect(gen.inputText, contains('Gradient descent'));
    expect(gen.promptVersion, AnnotationAiPromptVersions.define);
    expect(gen.provider, 'gemini');
    expect(gen.responseKind, 'text');
  });

  test(
    'persists DeepSeek provider metadata without overwriting Gemini versions',
    () async {
      final v1 = await history.generate(
        context: contextA,
        action: AiStudyAction.explain,
        selection: testGeminiSelection(),
        modelName: 'gemini-3.8-flash',
        provider: 'gemini',
      );
      final v2 = await history.generate(
        context: contextA,
        action: AiStudyAction.explain,
        selection: testGeminiSelection(),
        modelName: 'deepseek-flash',
        provider: 'deepseek',
        parentGenerationId: v1.id,
      );
      expect(v1.provider, 'gemini');
      expect(v2.provider, 'deepseek');
      expect(v2.modelName, 'deepseek-flash');
      expect(v2.generationNumber, 2);
      expect(v1.id, isNot(equals(v2.id)));
    },
  );

  test('delete all for action clears only that action', () async {
    await history.generate(
      context: contextA,
      action: AiStudyAction.summarize,
      selection: testGeminiSelection(),
    );
    await history.generate(
      context: contextA,
      selection: testGeminiSelection(),
      action: AiStudyAction.explain,
    );
    final fp = AnnotationAiSourceFingerprint.fromContext(contextA);

    await history.deleteAllForAction(
      sourceFingerprint: fp,
      action: AiStudyAction.summarize,
    );

    expect(
      await history.getGenerations(
        sourceFingerprint: fp,
        action: AiStudyAction.summarize,
      ),
      isEmpty,
    );
    expect(
      await history.getGenerations(
        sourceFingerprint: fp,
        action: AiStudyAction.explain,
      ),
      hasLength(1),
    );
  });

  test(
    'pin delete detaches annotation id but keeps generation snapshots',
    () async {
      final gen = await history.generate(
        context: contextA,
        action: AiStudyAction.summarize,
        selection: testGeminiSelection(),
      );
      await db.deleteStudyPin('ann-84');

      final kept = await history.getGeneration(gen.id);
      expect(kept, isNotNull);
      expect(kept!.annotationId, isNull);
      expect(kept.responseText, gen.responseText);
      expect(kept.inputText, contains('Gradient descent'));
    },
  );
}
