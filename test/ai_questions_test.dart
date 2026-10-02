import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/backup/backup_providers.dart';
import 'package:study_vault/core/backup/backup_service.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/services/ai_output_validator.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/ai_questions/domain/quiz_models.dart';
import 'package:study_vault/features/ai_questions/services/quiz_generation_service.dart';
import 'package:study_vault/features/ai_questions/services/quiz_session_service.dart';

void main() {
  group('schema / backup version alignment', () {
    test('schema version is 10 everywhere', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      expect(db.schemaVersion, 11);
      expect(kStudyVaultSchemaVersion, 10);
      expect(BackupService().currentSchemaVersion, 10);
      return db.close();
    });
  });

  group('QuestionSourceBuilder', () {
    test('fromSelectedText and fromPage normalize content', () {
      final selected = QuestionSourceBuilder.fromSelectedText(
        text: '  Hello   \n\n\n world  ',
        materialId: 'm1',
        pageNumber: 2,
      );
      expect(selected.type, QuestionSourceType.selectedText);
      expect(selected.text, 'Hello\n\nworld');
      expect(selected.pageNumbers, [2]);

      final page = QuestionSourceBuilder.fromPage(
        pageNumber: 3,
        pageText: 'Page body',
        materialId: 'm1',
      );
      expect(page.text, contains('--- Page 3 ---'));
      expect(page.text, contains('Page body'));
    });

    test('fromAnnotationsAndNotes merges both corpora', () {
      final source = QuestionSourceBuilder.fromAnnotationsAndNotes(
        annotations: const [
          AnnotationSourceItem(id: 'a1', shortText: 'Pin note', pageNumber: 1),
        ],
        notes: const [
          NoteSourceItem(id: 'n1', title: 'Lesson note', plainText: 'Body'),
        ],
      );
      expect(source.type, QuestionSourceType.annotationsAndNotes);
      expect(source.text, contains('Pin note'));
      expect(source.text, contains('Body'));
    });
  });

  group('AiOutputValidator.parseQuestions', () {
    test('parses valid MCQ', () {
      final result = AiOutputValidator.parseQuestions(
        '''
{
  "title": "Quiz",
  "questions": [{
    "type": "mcq",
    "question": "What is 2+2?",
    "options": ["3", "4", "5", "6"],
    "correctAnswer": 1,
    "explanation": "Basic arithmetic.",
    "difficulty": "easy",
    "sourcePage": 1
  }]
}
''',
        expectedCount: 1,
        requestedType: AiQuestionType.mcq,
      );
      expect(result.generated!.questions, hasLength(1));
      final q = result.generated!.questions.first;
      expect(q.type, QuizQuestionType.mcq);
      expect(q.options, hasLength(4));
      expect(q.correctAnswer, 1);
    });

    test('parses True/False', () {
      final result = AiOutputValidator.parseQuestions('''
{
  "title": "Quiz",
  "questions": [{
    "type": "true_false",
    "question": "Earth is round.",
    "correctAnswer": true,
    "explanation": "Supported by evidence.",
    "difficulty": "easy"
  }]
}
''', expectedCount: 1);
      expect(result.generated!.questions.first.correctAnswer, isTrue);
    });

    test('parses Short Answer and Fill Blank', () {
      final result = AiOutputValidator.parseQuestions('''
{
  "title": "Quiz",
  "questions": [
    {
      "type": "short_answer",
      "question": "Define gravity.",
      "correctAnswer": "Attraction between masses",
      "explanation": "From the text.",
      "difficulty": "medium"
    },
    {
      "type": "fill_blank",
      "question": "F = m____.",
      "correctAnswer": "a",
      "explanation": "Newton II.",
      "difficulty": "hard",
      "sourcePage": 4
    }
  ]
}
''', expectedCount: 2);
      expect(result.generated!.questions[0].type, QuizQuestionType.shortAnswer);
      expect(result.generated!.questions[1].type, QuizQuestionType.fillBlank);
      expect(result.generated!.questions[1].sourcePage, 4);
    });

    test('rejects wrong question count', () {
      expect(
        () => AiOutputValidator.parseQuestions('''
{"title":"Q","questions":[{
  "type":"short_answer","question":"Q1","correctAnswer":"A",
  "explanation":"E","difficulty":"easy"
}]}
''', expectedCount: 5),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });

    test('rejects invalid MCQ options', () {
      expect(
        () => AiOutputValidator.parseQuestions('''
{"title":"Q","questions":[{
  "type":"mcq","question":"Q","options":["A","B"],
  "correctAnswer":0,"explanation":"E","difficulty":"easy"
}]}
''', expectedCount: 1),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });

    test('rejects missing correct answer / malformed JSON', () {
      expect(
        () => AiOutputValidator.parseQuestions('''
{"title":"Q","questions":[{
  "type":"short_answer","question":"Q","correctAnswer":"",
  "explanation":"E","difficulty":"easy"
}]}
''', expectedCount: 1),
        throwsA(isA<AiMalformedOutputException>()),
      );
      expect(
        () => AiOutputValidator.parseQuestions('not-json'),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });
  });

  group('AiPromptBuilder.buildQuestions', () {
    test('includes assessment requirements and exact count', () {
      final prompt = AiPromptBuilder.buildQuestions(
        const AiStudyRequest(
          action: AiStudyAction.generateQuestions,
          sourceText: 'Source material about gradients.',
          questionType: AiQuestionType.mixed,
          questionCount: 10,
          questionDifficulty: AiQuestionDifficulty.hard,
        ),
      );
      expect(prompt, contains('educational assessment generator'));
      expect(prompt, contains('exactly 10 questions'));
      expect(prompt, contains('Return JSON only'));
      expect(prompt, contains('Do not return markdown'));
      expect(prompt, contains('Source material about gradients.'));
    });
  });

  group('QuizGrader + session', () {
    late AppDatabase db;
    late QuizSessionService session;
    late FakeAiService ai;
    late QuizGenerationService generation;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      session = QuizSessionService(db);
      ai = FakeAiService();
      generation = QuizGenerationService(
        db: db,
        ai: ai,
        settings: MemoryAiSettingsStore(),
      );

      final now = DateTime.now();
      await db.insertClass(
        ClassesCompanion.insert(
          id: 'c1',
          name: 'Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: 's1',
          classId: 'c1',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l1',
          subjectId: 's1',
          name: 'Lesson',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'm1',
          lessonId: 'l1',
          title: 'PDF',
          originalFileName: 'a.pdf',
          storedFileName: 'a.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() => db.close());

    test('persists exact requested count and scores retry', () async {
      final source = QuestionSourceBuilder.fromSelectedText(
        text: 'Gradient descent reduces the cost function.',
        materialId: 'm1',
        lessonId: 'l1',
        subjectId: 's1',
        pageNumber: 1,
      );
      final set = await generation.generateAndPersist(
        source: source,
        count: 5,
        type: QuizQuestionType.mixed,
        difficulty: QuizDifficulty.mixed,
      );
      expect(set.questionCount, 5);
      final questions = await session.loadQuestions(set.id);
      expect(questions, hasLength(5));

      final attempt = await session.startAttempt(questionSetId: set.id);
      for (final q in questions) {
        if (q.type == QuizQuestionType.mcq ||
            q.type == QuizQuestionType.trueFalse) {
          final correct = q.options.firstWhere((o) => o.isCorrect);
          await session.recordAnswer(
            attemptId: attempt.id,
            question: q,
            selectedOptionId: correct.id,
          );
        } else {
          await session.recordAnswer(
            attemptId: attempt.id,
            question: q,
            answerText: q.correctAnswer,
          );
        }
      }
      final score = await session.completeAttempt(attempt.id);
      expect(score.correctCount, 5);
      expect(score.percentage, 100);

      // Retry with wrong answers.
      final attempt2 = await session.startAttempt(questionSetId: set.id);
      for (final q in questions) {
        await session.recordAnswer(
          attemptId: attempt2.id,
          question: q,
          answerText: 'wrong',
          selectedOptionId: q.options.isEmpty
              ? null
              : q.options.firstWhere((o) => !o.isCorrect).id,
        );
      }
      final score2 = await session.completeAttempt(attempt2.id);
      expect(score2.correctCount, 0);
      expect(score2.incorrectCount, 5);

      final mistakes = await session.loadIncorrectQuestions(attempt2.id);
      expect(mistakes, hasLength(5));
    });

    test('does not persist when Gemini returns malformed output', () async {
      ai.handler = (request) async {
        throw const AiMalformedOutputException('bad');
      };
      expect(
        () => generation.generateAndPersist(
          source: QuestionSourceBuilder.fromSelectedText(text: 'x' * 20),
          count: 5,
          type: QuizQuestionType.mcq,
          difficulty: QuizDifficulty.easy,
        ),
        throwsA(isA<AiMalformedOutputException>()),
      );
      final sets = await db.watchQuestionSetsForLesson('l1').first;
      expect(sets, isEmpty);
    });
  });

  group('QuizGrader unit', () {
    test('normalizes short answers', () {
      const q = QuizQuestionView(
        id: '1',
        questionSetId: 's',
        type: QuizQuestionType.shortAnswer,
        question: 'Q',
        correctAnswer: 'Gradient Descent',
        explanation: 'E',
        difficulty: QuizDifficulty.easy,
        position: 0,
        options: [],
      );
      expect(
        QuizGrader.grade(question: q, answerText: '  gradient   descent '),
        isTrue,
      );
      expect(QuizGrader.grade(question: q, answerText: 'SGD'), isFalse);
    });
  });
}

/// Minimal in-memory settings for generation tests.
class MemoryAiSettingsStore implements AiSettingsStore {
  String _model = AiModelIds.recommended;
  AiLanguage _language = AiLanguage.auto;
  String? _preference;
  bool _privacy = true;

  @override
  Future<String> getModelId() async => _model;

  @override
  Future<void> setModelId(String id) async => _model = id;

  @override
  Future<AiLanguage> getLanguage() async => _language;

  @override
  Future<void> setLanguage(AiLanguage language) async => _language = language;

  @override
  Future<String?> getStudyPreference() async => _preference;

  @override
  Future<void> setStudyPreference(String? value) async => _preference = value;

  @override
  Future<bool> getPrivacyConsentAccepted() async => _privacy;

  @override
  Future<void> setPrivacyConsentAccepted(bool value) async => _privacy = value;

  @override
  Future<void> resetPrivacyConsent() => setPrivacyConsentAccepted(false);
}
