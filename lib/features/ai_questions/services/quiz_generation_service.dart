import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/services/ai_service.dart';
import '../domain/question_source.dart';
import '../domain/quiz_models.dart';
import 'pdf_page_image_extractor.dart';

const _uuid = Uuid();

/// Orchestrates source preparation → AI → strict validation → persistence.
///
/// The active AI provider only produces structured question data; this service
/// owns chunking, count enforcement, and transactional save (no partial quizzes).
class QuizGenerationService {
  QuizGenerationService({
    required this.db,
    required this.ai,
    required this.settings,
  });

  final AppDatabase db;
  final AiService ai;
  final AiSettingsStore settings;

  /// Soft per-request budget; larger sources are chunked.
  static const chunkSoftLimit = kAiSoftSourceLimit;

  Future<QuestionSet> generateAndPersist({
    required QuestionSource source,
    required int count,
    required QuizQuestionType type,
    required QuizDifficulty difficulty,
    AiPageSendMode sendMode = AiPageSendMode.text,
  }) async {
    assert(() {
      // ignore: avoid_print
      print(
        'QuizGen start type=${type.storageValue} count=$count '
        'difficulty=${difficulty.storageValue} '
        'send=${sendMode.name} '
        'sourceChars=${source.characterCount} pages=${source.pageTexts.length}',
      );
      return true;
    }());

    if (sendMode == AiPageSendMode.image) {
      if (source.type != QuestionSourceType.page ||
          source.pageNumbers.length != 1 ||
          source.filePath == null) {
        throw const AiMalformedOutputException(
          'Image send is only available for a single PDF page.',
        );
      }
    } else if (source.isEmpty) {
      throw const AiMalformedOutputException(
        'No study content available for this source.',
      );
    }
    if (count < 1 || count > 50) {
      throw const AiMalformedOutputException('Unsupported question count.');
    }

    try {
      final generated = await _generateWithChunking(
        source: source,
        count: count,
        type: type,
        difficulty: difficulty,
        sendMode: sendMode,
      );

      if (generated.quiz.questions.length != count) {
        throw AiMalformedOutputException(
          'Expected exactly $count questions, got ${generated.quiz.questions.length}.',
        );
      }

      final modelId = resolveActiveModelId(
        provider: await settings.getProvider(),
        storedModelId: await settings.getModelId(),
        action: AiStudyAction.generateQuestions,
      );
      final provider = await settings.getProvider();
      final set = await _persist(
        source: source,
        count: count,
        type: type,
        difficulty: difficulty,
        quiz: generated.quiz,
        modelId: modelId,
        provider: provider.storageValue,
        usage: generated.usage,
      );
      assert(() {
        // ignore: avoid_print
        print(
          'QuizGen persisted set=${set.id} questions=${generated.quiz.questions.length} '
          'mcq=${generated.quiz.questions.where((q) => q.isMcq).length} '
          'provider=${provider.storageValue} model=$modelId',
        );
        return true;
      }());
      return set;
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('QuizGen FAILED type=${type.storageValue} count=$count: $e');
        return true;
      }());
      rethrow;
    }
  }

  Future<({GeneratedQuiz quiz, AiTokenUsage? usage})> _generateWithChunking({
    required QuestionSource source,
    required int count,
    required QuizQuestionType type,
    required QuizDifficulty difficulty,
    AiPageSendMode sendMode = AiPageSendMode.text,
  }) async {
    final language = await settings.getLanguage();
    final preference = await settings.getStudyPreference();

    if (sendMode == AiPageSendMode.image) {
      final page = source.pageNumbers.first;
      final image = await PdfPageImageExtractor.renderJpeg(
        filePath: source.filePath!,
        pageNumber: page,
      );
      final label = source.text.trim().isEmpty
          ? 'PDF page $page (image attached)'
          : source.text;
      final part = await _callAi(
        text: label,
        count: count,
        type: type,
        difficulty: difficulty,
        language: language,
        preference: preference,
        image: image,
        pageNumber: page,
      );
      return (
        quiz: _stampSourcePage(part.quiz, page),
        usage: part.usage,
      );
    }

    if (source.characterCount <= kAiHardSourceLimit) {
      return _callAi(
        text: source.text,
        count: count,
        type: type,
        difficulty: difficulty,
        language: language,
        preference: preference,
      );
    }

    final chunks = _chunkSource(source);
    if (chunks.isEmpty) {
      throw const AiSourceTooLargeException();
    }

    final perChunk = _distributeCounts(count, chunks.length);
    final merged = <GeneratedQuizQuestion>[];
    final usages = <AiTokenUsage?>[];
    var title = 'Generated Quiz';

    for (var i = 0; i < chunks.length; i++) {
      final n = perChunk[i];
      if (n <= 0) continue;
      final part = await _callAi(
        text: chunks[i],
        count: n,
        type: type,
        difficulty: difficulty,
        language: language,
        preference: preference,
      );
      if (i == 0 && part.quiz.title.trim().isNotEmpty) title = part.quiz.title;
      merged.addAll(part.quiz.questions);
      usages.add(part.usage);
    }

    if (merged.length < count) {
      throw AiMalformedOutputException(
        'Could only generate ${merged.length} of $count questions '
        'from this material.',
      );
    }

    return (
      quiz: GeneratedQuiz(title: title, questions: merged.take(count).toList()),
      usage: AiTokenUsage.merge(usages),
    );
  }

  Future<({GeneratedQuiz quiz, AiTokenUsage? usage})> _callAi({
    required String text,
    required int count,
    required QuizQuestionType type,
    required QuizDifficulty difficulty,
    required AiLanguage language,
    String? preference,
    AiStudyImage? image,
    int? pageNumber,
  }) async {
    assert(() {
      // ignore: avoid_print
      print(
        'QuizGen AI call type=${type.storageValue} count=$count '
        'chunkChars=${text.length}'
        '${image == null ? '' : ' imageBytes=${image.bytes.length}'}',
      );
      return true;
    }());
    try {
      final result = await ai.generateQuestions(
        AiQuestionGenerationRequest(
          sourceText: text,
          count: count,
          type: _toAiType(type),
          difficulty: _toAiDifficulty(difficulty),
          language: language,
          userPreference: preference,
          pageNumber: pageNumber ?? image?.pageNumber,
          image: image,
        ),
      );
      final generated = result.generated;
      if (generated == null || generated.questions.length != count) {
        throw AiMalformedOutputException(
          'Expected exactly $count validated questions from AI.',
        );
      }
      return (quiz: generated, usage: result.usage);
    } on AiException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('QuizGen AI call FAILED: ${e.message}');
        return true;
      }());
      rethrow;
    }
  }

  static GeneratedQuiz _stampSourcePage(GeneratedQuiz quiz, int page) {
    return GeneratedQuiz(
      title: quiz.title,
      questions: [
        for (final q in quiz.questions)
          GeneratedQuizQuestion(
            type: q.type,
            question: q.question,
            correctAnswer: q.correctAnswer,
            explanation: q.explanation,
            difficulty: q.difficulty,
            options: q.options,
            sourcePage: q.sourcePage ?? page,
            sourceText: q.sourceText,
          ),
      ],
    );
  }

  List<String> _chunkSource(QuestionSource source) {
    if (source.pageTexts.isEmpty) {
      final text = source.text;
      final chunks = <String>[];
      var start = 0;
      while (start < text.length) {
        final end = (start + chunkSoftLimit).clamp(0, text.length);
        chunks.add(text.substring(start, end));
        start = end;
      }
      return chunks.where((c) => c.trim().isNotEmpty).toList();
    }

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final page in source.pageTexts) {
      final block = '--- Page ${page.pageNumber} ---\n${page.text.trim()}\n\n';
      if (buffer.length + block.length > chunkSoftLimit && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (block.length > chunkSoftLimit && buffer.isEmpty) {
        if (block.length > kAiHardSourceLimit) {
          chunks.add(block.substring(0, kAiHardSourceLimit));
        } else {
          chunks.add(block.trim());
        }
        continue;
      }
      buffer.write(block);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  List<int> _distributeCounts(int total, int buckets) {
    if (buckets <= 0) return const [];
    final base = total ~/ buckets;
    var remainder = total % buckets;
    return List.generate(buckets, (i) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      return base + extra;
    });
  }

  Future<QuestionSet> _persist({
    required QuestionSource source,
    required int count,
    required QuizQuestionType type,
    required QuizDifficulty difficulty,
    required GeneratedQuiz quiz,
    required String modelId,
    required String provider,
    AiTokenUsage? usage,
  }) async {
    final now = DateTime.now();
    final setId = _uuid.v4();
    final setEntry = QuestionSetsCompanion.insert(
      id: setId,
      materialId: Value(source.materialId),
      lessonId: Value(source.lessonId),
      subjectId: Value(source.subjectId),
      title: quiz.title.trim().isEmpty ? 'Generated Quiz' : quiz.title.trim(),
      sourceType: source.type.storageValue,
      sourceReference: Value(source.toSourceReferenceJson()),
      questionCount: count,
      questionType: type.storageValue,
      difficulty: difficulty.storageValue,
      aiProvider: Value(provider),
      aiModel: Value(modelId),
      promptTokens: Value(usage?.promptTokens),
      completionTokens: Value(usage?.completionTokens),
      totalTokens: Value(usage?.totalTokens),
      cacheHitTokens: Value(usage?.cacheHitTokens),
      cacheMissTokens: Value(usage?.cacheMissTokens),
      requestDurationMs: Value(usage?.durationMs),
      createdAt: now,
      updatedAt: now,
    );

    final questionEntries = <QuizQuestionsCompanion>[];
    final optionEntries = <QuizQuestionOptionsCompanion>[];

    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final qId = _uuid.v4();
      questionEntries.add(
        QuizQuestionsCompanion.insert(
          id: qId,
          questionSetId: setId,
          type: q.type.storageValue,
          question: q.question,
          correctAnswer: q.correctAnswerStorage,
          explanation: Value(q.explanation),
          difficulty: Value(q.difficulty.storageValue),
          sourcePage: Value(q.sourcePage),
          sourceText: Value(q.sourceText),
          position: i,
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (q.type == QuizQuestionType.mcq) {
        for (var oi = 0; oi < q.options.length; oi++) {
          optionEntries.add(
            QuizQuestionOptionsCompanion.insert(
              id: _uuid.v4(),
              questionId: qId,
              optionText: q.options[oi],
              isCorrect: oi == q.correctAnswer,
              position: oi,
            ),
          );
        }
      } else if (q.type == QuizQuestionType.trueFalse) {
        final correct = q.correctAnswer == true;
        optionEntries.add(
          QuizQuestionOptionsCompanion.insert(
            id: _uuid.v4(),
            questionId: qId,
            optionText: 'True',
            isCorrect: correct,
            position: 0,
          ),
        );
        optionEntries.add(
          QuizQuestionOptionsCompanion.insert(
            id: _uuid.v4(),
            questionId: qId,
            optionText: 'False',
            isCorrect: !correct,
            position: 1,
          ),
        );
      }
    }

    return db.persistGeneratedQuiz(
      setEntry: setEntry,
      questions: questionEntries,
      options: optionEntries,
    );
  }

  static AiQuestionType _toAiType(QuizQuestionType type) {
    return switch (type) {
      QuizQuestionType.mcq => AiQuestionType.mcq,
      QuizQuestionType.trueFalse => AiQuestionType.trueFalse,
      QuizQuestionType.shortAnswer => AiQuestionType.shortAnswer,
      QuizQuestionType.fillBlank => AiQuestionType.fillBlank,
      QuizQuestionType.mixed => AiQuestionType.mixed,
    };
  }

  static AiQuestionDifficulty _toAiDifficulty(QuizDifficulty d) {
    return switch (d) {
      QuizDifficulty.easy => AiQuestionDifficulty.easy,
      QuizDifficulty.medium => AiQuestionDifficulty.medium,
      QuizDifficulty.hard => AiQuestionDifficulty.hard,
      QuizDifficulty.mixed => AiQuestionDifficulty.mixed,
    };
  }
}
