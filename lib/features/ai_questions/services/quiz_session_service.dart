import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/quiz_models.dart';

const _uuid = Uuid();

/// Loads question sets and runs Study Mode quiz attempts.
class QuizSessionService {
  QuizSessionService(this.db);

  final AppDatabase db;

  Future<List<QuizQuestionView>> loadQuestions(String questionSetId) async {
    final set = await db.getQuestionSetById(questionSetId);
    final rows = await db.getQuizQuestionsForSet(questionSetId);
    final options = await db.getOptionsForQuestions([
      for (final q in rows) q.id,
    ]);
    final byQuestion = <String, List<QuizQuestionOption>>{};
    for (final o in options) {
      (byQuestion[o.questionId] ??= []).add(o);
    }

    return [
      for (final q in rows)
        QuizQuestionView(
          id: q.id,
          questionSetId: q.questionSetId,
          type: QuizQuestionTypeX.fromStorage(q.type),
          question: q.question,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          difficulty: QuizDifficultyX.fromStorage(q.difficulty),
          position: q.position,
          sourcePage: q.sourcePage,
          sourceText: q.sourceText,
          materialId: set?.materialId,
          options: [
            for (final o in (byQuestion[q.id] ?? const <QuizQuestionOption>[]))
              QuizOptionView(
                id: o.id,
                text: o.optionText,
                isCorrect: o.isCorrect,
                position: o.position,
              ),
          ],
        ),
    ];
  }

  Future<QuizAttempt> startAttempt({
    required String questionSetId,
    QuizPlayMode mode = QuizPlayMode.study,
  }) async {
    final questions = await db.getQuizQuestionsForSet(questionSetId);
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.insertQuizAttempt(
      QuizAttemptsCompanion.insert(
        id: id,
        questionSetId: questionSetId,
        startedAt: now,
        totalQuestions: questions.length,
        mode: Value(mode.name),
      ),
    );
    return (await db.getQuizAttemptById(id))!;
  }

  Future<bool> recordAnswer({
    required String attemptId,
    required QuizQuestionView question,
    String? selectedOptionId,
    String? answerText,
  }) async {
    final correct = QuizGrader.grade(
      question: question,
      selectedOptionId: selectedOptionId,
      answerText: answerText,
    );
    await db.saveQuizAnswer(
      id: _uuid.v4(),
      quizAttemptId: attemptId,
      questionId: question.id,
      selectedOptionId: selectedOptionId,
      answerText: answerText,
      isCorrect: correct,
    );
    return correct;
  }

  Future<QuizScore> completeAttempt(String attemptId) async {
    final attempt = await db.getQuizAttemptById(attemptId);
    if (attempt == null) {
      throw StateError('Quiz attempt not found');
    }
    final answers = await db.getQuizAnswersForAttempt(attemptId);
    final correctCount = answers.where((a) => a.isCorrect == true).length;
    final incorrectCount = answers.where((a) => a.isCorrect == false).length;
    final total = attempt.totalQuestions;
    final score = total == 0 ? 0 : ((correctCount / total) * 100).round();

    await db.updateQuizAttempt(
      attempt.copyWith(completedAt: Value(DateTime.now()), score: Value(score)),
    );

    return QuizScore(
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      totalQuestions: total,
      score: score,
    );
  }

  Future<List<QuizQuestionView>> loadIncorrectQuestions(
    String attemptId,
  ) async {
    final attempt = await db.getQuizAttemptById(attemptId);
    if (attempt == null) return const [];
    final answers = await db.getQuizAnswersForAttempt(attemptId);
    final incorrectIds = {
      for (final a in answers)
        if (a.isCorrect == false) a.questionId,
    };
    if (incorrectIds.isEmpty) return const [];
    final all = await loadQuestions(attempt.questionSetId);
    return [
      for (final q in all)
        if (incorrectIds.contains(q.id)) q,
    ];
  }
}
