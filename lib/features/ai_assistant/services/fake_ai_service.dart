import '../../ai_questions/domain/quiz_models.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import 'ai_service.dart';

/// Deterministic offline fake for unit/widget tests.
class FakeAiService implements AiService {
  FakeAiService({
    this.configured = true,
    this.testConnectionSucceeds = true,
    this.handler,
  });

  bool configured;
  bool testConnectionSucceeds;
  Future<AiStudyResult> Function(AiStudyRequest request)? handler;

  @override
  Future<bool> get isConfigured async => configured;

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!configured) throw const AiNotConfiguredException();
    if (!testConnectionSucceeds) throw const AiInvalidKeyException();
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!configured) throw const AiNotConfiguredException();
    if (handler != null) return handler!(request);

    return switch (request.action) {
      AiStudyAction.explain => AiTextResult(
        markdown:
            '## Explanation\n\n${request.sourceText}\n\n'
            'This is a clear study explanation.',
      ),
      AiStudyAction.simplify ||
      AiStudyAction.rephrase ||
      AiStudyAction.fixGrammar => AiTextResult(
        markdown: 'Simplified: ${request.sourceText}',
      ),
      AiStudyAction.organize => AiTextResult(
        markdown:
            '# Organized Notes\n\n## Summary\n\n'
            '- ${request.sourceText.split('\n').first}\n',
      ),
      AiStudyAction.summarize => AiTextResult(
        markdown: '- Key point from source text',
      ),
      AiStudyAction.keyConcepts => AiTextResult(
        markdown: '- **Concept** — short definition from the source',
      ),
      AiStudyAction.examPoints => AiTextResult(
        markdown:
            '### Important concept\n\nFrom the source.\n\n'
            '### Common confusion\n\nStudents may mix related terms.\n\n'
            '### Practice question\n\nWhat is the main idea?',
      ),
      AiStudyAction.define ||
      AiStudyAction.giveExample ||
      AiStudyAction.translate ||
      AiStudyAction.askAi ||
      AiStudyAction.customPrompt => AiTextResult(
        markdown:
            'AI response for ${request.action.name}:\n\n${request.sourceText}',
      ),
      AiStudyAction.createAnnotation => AiAnnotationDraft(
        shortDescription: 'AI Draft',
        fullNoteMarkdown: '## Note\n\n${request.sourceText}',
        suggestedCategory: categoryNameToId['Definition'],
      ),
      AiStudyAction.generateFlashcards => AiFlashcardsResult(
        cards: List.generate(
          request.flashcardCount.clamp(1, 20),
          (i) => AiFlashcardDraft(
            front: 'Q${i + 1} from study text?',
            back: 'A${i + 1}',
          ),
        ),
      ),
      AiStudyAction.generateQuestions => await generateQuestions(
        request.toQuestionGenerationRequest(),
      ),
    };
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!configured) throw const AiNotConfiguredException();
    if (handler != null) {
      final result = await handler!(request.toStudyRequest());
      if (result is AiQuestionsResult) return result;
      throw const AiMalformedOutputException(
        'Fake handler did not return questions.',
      );
    }
    final count = request.count.clamp(1, 50);
    final type = request.type == AiQuestionType.mixed ? null : request.type;
    final questions = <GeneratedQuizQuestion>[];
    for (var i = 0; i < count; i++) {
      if (type == null) {
        questions.add(_fakeQuestionKind(_mixedType(i), i));
      } else {
        questions.add(_fakeQuestion(type, i));
      }
    }
    final generated = GeneratedQuiz(
      title: 'Generated Quiz',
      questions: questions,
    );
    return AiQuestionsResult(
      title: generated.title,
      questions: [
        for (final q in questions)
          AiQuestionDraft(
            question: q.question,
            answer: q.correctAnswerStorage,
            type: q.type,
            choices: q.options.isEmpty ? null : q.options,
            correctIndex: q.isMcq ? q.correctAnswer as int : null,
            explanation: q.explanation,
            difficulty: q.difficulty,
            sourcePage: q.sourcePage,
          ),
      ],
      generated: generated,
    );
  }

  QuizQuestionType _mixedType(int index) {
    const cycle = [
      QuizQuestionType.mcq,
      QuizQuestionType.trueFalse,
      QuizQuestionType.shortAnswer,
      QuizQuestionType.fillBlank,
    ];
    return cycle[index % cycle.length];
  }

  GeneratedQuizQuestion _fakeQuestion(AiQuestionType? type, int index) {
    final kind = switch (type) {
      AiQuestionType.mcq => QuizQuestionType.mcq,
      AiQuestionType.trueFalse => QuizQuestionType.trueFalse,
      AiQuestionType.shortAnswer => QuizQuestionType.shortAnswer,
      AiQuestionType.fillBlank => QuizQuestionType.fillBlank,
      AiQuestionType.mixed || null => _mixedType(index),
    };
    return _fakeQuestionKind(kind, index);
  }

  GeneratedQuizQuestion _fakeQuestionKind(QuizQuestionType kind, int index) {
    final n = index + 1;
    return switch (kind) {
      QuizQuestionType.mcq => GeneratedQuizQuestion(
        type: QuizQuestionType.mcq,
        question: 'MCQ $n: What is covered in the source?',
        options: const ['Option A', 'Option B', 'Option C', 'Option D'],
        correctAnswer: 0,
        explanation: 'Option A matches the source.',
        difficulty: QuizDifficulty.medium,
        sourcePage: 1,
      ),
      QuizQuestionType.trueFalse => GeneratedQuizQuestion(
        type: QuizQuestionType.trueFalse,
        question: 'TF $n: The source discusses this topic.',
        correctAnswer: true,
        explanation: 'The statement is supported by the source.',
        difficulty: QuizDifficulty.easy,
        sourcePage: 1,
        options: const ['True', 'False'],
      ),
      QuizQuestionType.shortAnswer => GeneratedQuizQuestion(
        type: QuizQuestionType.shortAnswer,
        question: 'SA $n: Name a key idea from the source.',
        correctAnswer: 'Key idea $n',
        explanation: 'Derived from the supplied material.',
        difficulty: QuizDifficulty.medium,
        sourcePage: 1,
      ),
      QuizQuestionType.fillBlank => GeneratedQuizQuestion(
        type: QuizQuestionType.fillBlank,
        question: 'FIB $n: The main concept is _____.',
        correctAnswer: 'concept $n',
        explanation: 'Fill-in answer from the source.',
        difficulty: QuizDifficulty.hard,
        sourcePage: 1,
      ),
      QuizQuestionType.mixed => GeneratedQuizQuestion(
        type: QuizQuestionType.shortAnswer,
        question: 'Q$n',
        correctAnswer: 'A$n',
        explanation: 'Explanation $n',
        difficulty: QuizDifficulty.medium,
      ),
    };
  }
}

extension on AiStudyRequest {
  AiQuestionGenerationRequest toQuestionGenerationRequest() {
    return AiQuestionGenerationRequest(
      sourceText: sourceText,
      count: questionCount,
      type: questionType ?? AiQuestionType.mixed,
      difficulty: questionDifficulty,
      language: language,
      userPreference: userPreference,
    );
  }
}
