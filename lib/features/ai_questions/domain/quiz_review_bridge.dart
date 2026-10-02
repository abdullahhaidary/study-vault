import 'quiz_models.dart';

/// Extension point: incorrect quiz answers can later join spaced Review.
///
/// Today, Study Review is pin-based and does not schedule due dates. This
/// bridge documents the integration surface without changing pin Review
/// behavior.
///
/// Future work:
/// - Map [QuizMistakeItem] → reviewable items with optional material/page
/// - Optionally seed flashcards (see Create Flashcards from Mistakes)
/// - Add Exam Mode ([QuizPlayMode.exam]) that defers grading until submit
abstract final class QuizReviewBridge {
  /// Builds mistake items from a completed attempt's incorrect answers.
  static List<QuizMistakeItem> fromIncorrectQuestions(
    List<QuizQuestionView> incorrect,
  ) {
    return [
      for (final q in incorrect)
        QuizMistakeItem(
          questionId: q.id,
          questionSetId: q.questionSetId,
          prompt: q.question,
          expectedAnswer: q.correctAnswer,
          explanation: q.explanation,
          materialId: q.materialId,
          sourcePage: q.sourcePage,
        ),
    ];
  }
}

class QuizMistakeItem {
  const QuizMistakeItem({
    required this.questionId,
    required this.questionSetId,
    required this.prompt,
    required this.expectedAnswer,
    this.explanation,
    this.materialId,
    this.sourcePage,
  });

  final String questionId;
  final String questionSetId;
  final String prompt;
  final String expectedAnswer;
  final String? explanation;
  final String? materialId;
  final int? sourcePage;
}
