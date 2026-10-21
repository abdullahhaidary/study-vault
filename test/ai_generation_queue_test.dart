import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_generation_queue/data/ai_generation_job_repository.dart';
import 'package:study_vault/features/ai_generation_queue/data/ai_generation_providers.dart';
import 'package:study_vault/features/ai_generation_queue/domain/ai_generation_models.dart';
import 'package:study_vault/features/ai_generation_queue/presentation/generation_queue_host.dart';
import 'package:study_vault/features/ai_generation_queue/presentation/generation_queue_indicator.dart';
import 'package:study_vault/features/ai_generation_queue/services/ai_generation_coordinator.dart';
import 'package:study_vault/features/ai_generation_queue/services/ai_generation_runner.dart';
import 'package:study_vault/features/ai_generation_queue/services/pdf_material_generation_runner.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';
import 'package:study_vault/features/pdf_ai_materials/presentation/pdf_ai_queue_actions.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_translation_service.dart';
import 'helpers/ai_selection_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('five jobs are accepted and only two run', () async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    for (var i = 0; i < 5; i++) {
      await harness.enqueue(materialId: 'm$i', title: 'Lesson $i');
    }
    await harness.flush();
    expect(harness.coordinator.current, hasLength(5));
    expect(harness.runner.started, hasLength(2));
    expect(
      harness.coordinator.current.where(
        (job) => job.status == AiGenerationJobStatus.running,
      ),
      hasLength(2),
    );
    expect(
      harness.coordinator.current.where(
        (job) => job.status == AiGenerationJobStatus.queued,
      ),
      hasLength(3),
    );
  });

  test('FIFO continues after success and failure', () async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    for (final title in ['A', 'B', 'C', 'D']) {
      await harness.enqueue(materialId: title, title: title);
    }
    await harness.flush();
    expect(harness.runner.started, ['A', 'B']);

    harness.runner.finish(
      'A',
      const AiGenerationRunFailure(
        message: 'The model returned malformed output.',
        category: AiGenerationErrorCategory.malformedOutput,
      ),
    );
    await harness.flush();
    expect(harness.runner.started, ['A', 'B', 'C']);

    harness.runner.finish(
      'B',
      const AiGenerationRunSuccess(resultMaterialId: 'version-b'),
    );
    await harness.flush();
    expect(harness.runner.started, ['A', 'B', 'C', 'D']);
    expect(
      harness.coordinator.current.singleWhere((job) => job.title == 'A').status,
      AiGenerationJobStatus.failed,
    );
    expect(
      harness.coordinator.current.singleWhere((job) => job.title == 'B').status,
      AiGenerationJobStatus.completed,
    );
  });

  test(
    'duplicate active jobs for the same material and type are rejected',
    () async {
      final harness = await _Harness.scripted();
      addTearDown(harness.close);
      await harness.enqueue(materialId: 'pdf', title: 'Lecture');
      await harness.flush();
      await expectLater(
        harness.enqueue(materialId: 'pdf', title: 'Lecture'),
        throwsA(isA<DuplicateAiGenerationException>()),
      );
      harness.runner.finish(
        'Lecture',
        const AiGenerationRunSuccess(resultMaterialId: 'v1'),
      );
      await harness.flush();
      await harness.enqueue(materialId: 'pdf', title: 'Lecture');
      expect(harness.coordinator.current, hasLength(2));
    },
  );

  test(
    'success saves a version and failure stays under needs attention',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final client = _QueueClient(
        (messages) => const PdfAiCompletion(
          markdown: '# Summary\nSaved study notes.',
          provider: 'deepseek',
          model: 'deepseek-chat',
        ),
      );
      final harness = await _Harness.withMaterials(db, client);
      addTearDown(harness.close);
      await harness.enqueue(materialId: 'pdf-1', title: 'PDF');
      await harness.waitUntilIdle();
      final job = harness.coordinator.current.single;
      expect(job.status, AiGenerationJobStatus.completed);
      expect(job.resultMaterialId, isNotNull);
      final saved = await harness.materials.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      );
      expect(saved, hasLength(1));
      expect(saved.single.content, contains('Saved study notes'));

      final failing = _QueueClient((_) => throw StateError('malformed output'));
      final failed = await _Harness.withMaterials(db, failing);
      addTearDown(failed.close);
      await failed.enqueue(materialId: 'pdf-1', title: 'PDF');
      await failed.waitUntilIdle();
      final attention = failed.coordinator.current.singleWhere(
        (job) => job.status == AiGenerationJobStatus.failed,
      );
      expect(attention.status, AiGenerationJobStatus.failed);
      expect(attention.needsAttention, isTrue);
      expect(
        await failed.materials.history(
          materialId: 'pdf-1',
          type: PdfAiMaterialType.summary,
        ),
        hasLength(1),
      );
    },
  );

  test('partial New API output is not saved as a completed material', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    const partial = 'This partial study note is long enough to keep.';
    final client = _QueueClient(
      (_) => const PdfAiCompletion(
        markdown: partial,
        provider: 'newApi',
        model: 'claude',
        disposition: AiCompletionDisposition.partialConnection,
      ),
    );
    final harness = await _Harness.withMaterials(
      db,
      client,
      provider: AiProviderId.newApi,
    );
    addTearDown(harness.close);
    await harness.enqueue(materialId: 'pdf-1', title: 'PDF');
    await harness.waitUntilIdle();
    final job = harness.coordinator.current.single;
    expect(job.status, AiGenerationJobStatus.partial);
    expect(job.partialOutput, partial);
    expect(job.resultMaterialId, isNull);
    expect(
      await harness.materials.history(
        materialId: 'pdf-1',
        type: PdfAiMaterialType.summary,
      ),
      isEmpty,
    );
  });

  test('continuing a partial result saves merged output', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    var continued = false;
    final client = _QueueClient((messages) {
      final text = messages.map((message) => message['content']).join('\n');
      if (text.contains('CONTINUE REQUEST')) {
        continued = true;
        return const PdfAiCompletion(
          markdown: '# Continued\nThe rest of the explanation.',
          provider: 'newApi',
          model: 'claude',
        );
      }
      return const PdfAiCompletion(
        markdown: 'The first half of the study note.\n',
        provider: 'newApi',
        model: 'claude',
        disposition: AiCompletionDisposition.partialConnection,
      );
    });
    final harness = await _Harness.withMaterials(
      db,
      client,
      provider: AiProviderId.newApi,
    );
    addTearDown(harness.close);
    await harness.enqueue(materialId: 'pdf-1', title: 'PDF');
    await harness.waitUntilIdle();
    final partial = harness.coordinator.current.single;
    expect(partial.status, AiGenerationJobStatus.partial);
    await harness.coordinator.continuePartial(partial.id);
    await harness.waitUntilIdle();
    expect(continued, isTrue);
    final jobs = harness.coordinator.current;
    final child = jobs.singleWhere((job) => job.parentJobId == partial.id);
    expect(child.status, AiGenerationJobStatus.completed);
    expect(
      jobs.singleWhere((job) => job.id == partial.id).supersededByJobId,
      child.id,
    );
    final saved = await harness.materials.history(
      materialId: 'pdf-1',
      type: PdfAiMaterialType.summary,
    );
    expect(saved, hasLength(1));
    expect(saved.single.content, contains('The first half'));
    expect(saved.single.content, contains('The rest of the explanation'));
  });

  test('completed chunk checkpoints are reused', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    var digestCalls = 0;
    var failAfter = 2;
    final client = _QueueClient((messages) {
      final text = messages.map((message) => message['content']).join('\n');
      if (text.contains('source segment')) {
        digestCalls++;
        if (digestCalls > failAfter) {
          throw StateError('stop after two digests');
        }
        return PdfAiCompletion(
          markdown: 'Digest $digestCalls',
          provider: 'deepseek',
          model: 'deepseek-chat',
        );
      }
      return const PdfAiCompletion(
        markdown: '# Summary\nFrom the saved digests.',
        provider: 'deepseek',
        model: 'deepseek-chat',
      );
    });
    final harness = await _Harness.withMaterials(
      db,
      client,
      pages: [SourcePageText(pageNumber: 1, text: 'a' * 240001)],
    );
    addTearDown(harness.close);
    await harness.enqueue(materialId: 'pdf-1', title: 'PDF');
    await harness.waitUntilIdle();
    final failed = harness.coordinator.current.single;
    expect(failed.status, AiGenerationJobStatus.failed);
    expect(failed.checkpoint?.digests, hasLength(2));
    final beforeRetry = digestCalls;
    final remaining =
        failed.checkpoint!.chunkCount - failed.checkpoint!.digests.length;
    failAfter = 100;
    await harness.coordinator.retry(failed.id);
    await harness.waitUntilIdle();
    expect(remaining, greaterThan(0));
    expect(remaining, lessThan(failed.checkpoint!.chunkCount));
    expect(digestCalls - beforeRetry, remaining);
    final child = harness.coordinator.current.singleWhere(
      (job) => job.parentJobId == failed.id,
    );
    expect(child.status, AiGenerationJobStatus.completed);
  });

  test('startup recovery resumes queued work and marks dead runs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = AiGenerationJobRepository(db);
    final now = DateTime.utc(2026, 10, 21);
    await repository.save(
      _stored(id: 'queued', status: AiGenerationJobStatus.queued, now: now),
    );
    await repository.save(
      _stored(
        id: 'running-empty',
        status: AiGenerationJobStatus.running,
        now: now,
        materialId: 'other',
      ),
    );
    await repository.save(
      _stored(
        id: 'running-partial',
        status: AiGenerationJobStatus.running,
        now: now,
        materialId: 'partial-doc',
        partialOutput: 'Kept partial text',
      ),
    );
    await repository.save(
      _stored(
        id: 'waiting',
        status: AiGenerationJobStatus.waitingToRetry,
        now: now,
        materialId: 'waiting-doc',
      ),
    );
    final runner = _ScriptedRunner();
    final coordinator = AiGenerationCoordinator(
      repository: repository,
      runner: runner,
      delay: (_) async {},
      clock: () => now,
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();
    await _flush();
    final jobs = {for (final job in coordinator.current) job.id: job};
    expect(jobs['queued']!.status, AiGenerationJobStatus.running);
    expect(jobs['waiting']!.status, AiGenerationJobStatus.running);
    expect(jobs['running-empty']!.status, AiGenerationJobStatus.interrupted);
    expect(jobs['running-empty']!.canRetry, isTrue);
    expect(jobs['running-partial']!.status, AiGenerationJobStatus.partial);
    expect(jobs['running-partial']!.partialOutput, 'Kept partial text');
    expect(runner.started, isNot(contains('running-empty')));
  });

  test('Persian failure keeps the completed original', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final client = _QueueClient((messages) {
      final text = messages.map((message) => message['content']).join('\n');
      if (text.contains('Persian (Farsi)')) {
        throw StateError('translation unavailable');
      }
      return const PdfAiCompletion(
        markdown: '# Summary\nOriginal English notes.',
        provider: 'deepseek',
        model: 'deepseek-chat',
      );
    });
    final harness = await _Harness.withMaterials(db, client);
    addTearDown(harness.close);
    await harness.enqueue(
      materialId: 'pdf-1',
      title: 'PDF',
      translateToPersian: true,
    );
    await harness.waitUntilIdle();
    final job = harness.coordinator.current.single;
    expect(job.status, AiGenerationJobStatus.completedWithWarning);
    expect(job.resultMaterialId, isNotNull);
    expect(job.canRetryTranslation, isTrue);
    final saved = await harness.materials.history(
      materialId: 'pdf-1',
      type: PdfAiMaterialType.summary,
    );
    expect(saved.single.content, contains('Original English notes'));
  });

  test('persisted request JSON does not contain API keys', () async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    await harness.enqueue(materialId: 'pdf', title: 'PDF');
    final row = await harness.db
        .customSelect('SELECT request_json FROM local_ai_generation_jobs')
        .getSingle();
    final raw = row.read<String>('request_json');
    final json = jsonDecode(raw) as Map<String, Object?>;
    expect(raw.toLowerCase(), isNot(contains('apikey')));
    expect(raw.toLowerCase(), isNot(contains('api_key')));
    expect(raw.toLowerCase(), isNot(contains('authorization')));
    expect(raw, isNot(contains('sk-')));
    expect(json['v'], 1);
    expect(json.keys, isNot(contains('apiKey')));
  });

  testWidgets('a job keeps running after its screen is disposed', (
    tester,
  ) async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    await tester.pumpWidget(
      _app(
        harness,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(harness.enqueue(materialId: 'pdf', title: 'Lecture'));
            },
            child: const Text('Generate'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Generate'));
    await tester.pump();
    await tester.runAsync(_flush);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      harness.coordinator.current.single.status,
      AiGenerationJobStatus.running,
    );
    harness.runner.finish(
      'Lecture',
      const AiGenerationRunSuccess(resultMaterialId: 'v1'),
    );
    await tester.runAsync(_flush);
    expect(
      harness.coordinator.current.single.status,
      AiGenerationJobStatus.completed,
    );
  });

  testWidgets('returning to a material shows the queued or running state', (
    tester,
  ) async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    await harness.enqueue(materialId: 'pdf-1', title: 'PDF');
    await harness.enqueue(materialId: 'pdf-2', title: 'Other');
    await harness.enqueue(materialId: 'pdf-3', title: 'Third');
    await harness.flush();
    await tester.pumpWidget(
      _app(
        harness,
        home: const PdfAiQueueBanner(
          materialId: 'pdf-3',
          type: PdfAiMaterialType.summary,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('View in Generation Center'), findsOneWidget);
  });

  testWidgets('the indicator shows running, queued, and attention counts', (
    tester,
  ) async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    for (final title in ['A', 'B', 'C', 'D']) {
      await harness.enqueue(materialId: title, title: title);
    }
    await harness.flush();
    harness.runner.finish(
      'A',
      const AiGenerationRunFailure(
        message: 'Rate limit',
        category: AiGenerationErrorCategory.malformedOutput,
      ),
    );
    await harness.flush();
    await tester.pumpWidget(
      _app(harness, home: const GenerationQueueIndicator(onOpen: _noop)),
    );
    await tester.pump();
    expect(find.text('2 generating'), findsOneWidget);
    expect(find.text('1 queued'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    final failed = harness.coordinator.current.singleWhere(
      (job) => job.title == 'A',
    );
    await harness.coordinator.remove(failed.id);
    for (final title in ['B', 'C', 'D']) {
      harness.runner.finish(
        title,
        const AiGenerationRunSuccess(resultMaterialId: 'done'),
      );
      await harness.flush();
    }
    await tester.pump();
    expect(find.text('3 ready'), findsOneWidget);
  });

  testWidgets('removing the originating route does not hide completion', (
    tester,
  ) async {
    final harness = await _Harness.scripted();
    addTearDown(harness.close);
    await tester.pumpWidget(
      _app(
        harness,
        home: GenerationQueueHost(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Text('Studying something else'),
                ),
              ),
              child: const Text('Leave'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final job = await harness.enqueue(materialId: 'pdf', title: 'Lecture');
    await tester.runAsync(harness.flush);
    Navigator.of(tester.element(find.text('Studying something else'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    harness.runner.finish(
      'Lecture',
      const AiGenerationRunSuccess(resultMaterialId: 'v1'),
    );
    await tester.runAsync(_flush);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('${job.typeLabel} for Lecture is ready'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });
}

void _noop() {}

Future<void> _flush() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.value();
  }
}

Widget _app(_Harness harness, {required Widget home}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(harness.db),
      aiGenerationCoordinatorProvider.overrideWithValue(harness.coordinator),
    ],
    child: MaterialApp(home: Scaffold(body: home)),
  );
}

class _Harness {
  _Harness.raw(
    this.db,
    this.coordinator,
    this.runner,
    this.materials, {
    required this.ownsDatabase,
  });

  final AppDatabase db;
  final AiGenerationCoordinator coordinator;
  final _ScriptedRunner runner;
  final PdfAiMaterialService materials;
  final bool ownsDatabase;

  static Future<_Harness> scripted() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final runner = _ScriptedRunner();
    final coordinator = AiGenerationCoordinator(
      repository: AiGenerationJobRepository(db),
      runner: runner,
      delay: (_) async {},
    );
    await coordinator.start();
    return _Harness.raw(
      db,
      coordinator,
      runner,
      _unusedService(db),
      ownsDatabase: true,
    );
  }

  static Future<_Harness> withMaterials(
    AppDatabase db,
    _QueueClient client, {
    AiProviderId provider = AiProviderId.deepseek,
    List<SourcePageText>? pages,
  }) async {
    final materials = PdfAiMaterialService(
      db,
      client,
      textSource: _TextSource(
        pages ?? [const SourcePageText(pageNumber: 1, text: 'Lecture text.')],
      ),
    );
    final translations = PdfAiTranslationService(db, client);
    final runner = _ScriptedRunner();
    final coordinator = AiGenerationCoordinator(
      repository: AiGenerationJobRepository(db),
      runner: PdfMaterialGenerationRunner(materials, translations),
      delay: (_) async {},
    );
    await coordinator.start();
    final harness = _Harness.raw(
      db,
      coordinator,
      runner,
      materials,
      ownsDatabase: false,
    );
    harness.provider = provider;
    return harness;
  }

  AiProviderId provider = AiProviderId.deepseek;

  Future<AiGenerationJob> enqueue({
    required String materialId,
    required String title,
    bool translateToPersian = false,
  }) {
    final selection = provider == AiProviderId.newApi
        ? testGeminiSelection()
        : testDeepSeekSelection();
    return coordinator.enqueue(
      AiGenerationEnqueue(
        materialId: materialId,
        title: title,
        filePath: '/tmp/$materialId.pdf',
        type: PdfAiMaterialType.summary,
        provider: provider.storageValue,
        requestedModelId: selection.requestedModelId,
        resolvedModelId: provider == AiProviderId.newApi
            ? 'claude'
            : selection.resolvedModelId,
        request: AiGenerationRequestPayload(
          translateToPersian: translateToPersian,
        ),
      ),
    );
  }

  Future<void> flush() => _flush();

  Future<void> waitUntilIdle() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      final busy = coordinator.current.any(
        (job) =>
            job.status == AiGenerationJobStatus.queued ||
            job.status == AiGenerationJobStatus.running ||
            job.status == AiGenerationJobStatus.waitingToRetry ||
            job.status == AiGenerationJobStatus.cancelRequested,
      );
      if (coordinator.current.isNotEmpty && !busy) return;
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError(
      'Jobs did not settle: '
      '${coordinator.current.map((job) => '${job.title}:${job.status.name}').join(', ')}',
    );
  }

  Future<void> close() async {
    await coordinator.dispose();
    if (ownsDatabase) await db.close();
  }
}

PdfAiMaterialService _unusedService(AppDatabase db) {
  return PdfAiMaterialService(
    db,
    _QueueClient((_) => throw StateError('unused')),
  );
}

class _ScriptedRunner implements AiGenerationRunner {
  final started = <String>[];
  final _gates = <String, Completer<AiGenerationRunResult>>{};

  @override
  Future<AiGenerationRunResult> run(
    AiGenerationJob job,
    AiGenerationRunControl control,
  ) {
    started.add(job.title);
    final gate = Completer<AiGenerationRunResult>();
    _gates[job.title] = gate;
    return gate.future;
  }

  void finish(String title, AiGenerationRunResult result) {
    _gates[title]!.complete(result);
  }

  @override
  Future<String> savePartial(AiGenerationJob job) async => 'saved-partial';
}

class _QueueClient implements PdfAiCompletionClient {
  _QueueClient(this._next);

  final PdfAiCompletion Function(List<Map<String, String>> messages) _next;

  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    void Function(String partialText)? onPartialText,
  }) async {
    final result = _next(messages);
    if (result.disposition != AiCompletionDisposition.complete) {
      onPartialText?.call(result.markdown);
    }
    return result;
  }
}

class _TextSource implements PdfDocumentTextSource {
  _TextSource(this.pages);
  final List<SourcePageText> pages;

  @override
  Future<List<SourcePageText>> extractAllPages(String filePath) async => pages;
}

AiGenerationJob _stored({
  required String id,
  required AiGenerationJobStatus status,
  required DateTime now,
  String materialId = 'pdf',
  String? partialOutput,
}) {
  return AiGenerationJob(
    id: id,
    operationKind: AiGenerationOperationKind.pdfMaterial,
    materialId: materialId,
    lessonId: null,
    title: id,
    filePath: '/tmp/$id.pdf',
    materialType: PdfAiMaterialType.summary,
    provider: 'deepseek',
    requestedModelId: 'deepseek-chat',
    resolvedModelId: 'deepseek-chat',
    thinkingMode: null,
    status: status,
    phase: status == AiGenerationJobStatus.queued
        ? AiGenerationPhase.waiting
        : AiGenerationPhase.generatingFinalOutput,
    progressCurrent: 0,
    progressTotal: 0,
    attemptCount: status == AiGenerationJobStatus.queued ? 0 : 1,
    request: const AiGenerationRequestPayload(),
    partialOutput: partialOutput,
    checkpoint: null,
    resultMaterialId: null,
    errorMessage: null,
    errorCategory: null,
    parentJobId: null,
    supersededByJobId: null,
    warningMessage: null,
    createdAt: now,
    startedAt: status == AiGenerationJobStatus.queued ? null : now,
    updatedAt: now,
    completedAt: null,
  );
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 21);
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
}
