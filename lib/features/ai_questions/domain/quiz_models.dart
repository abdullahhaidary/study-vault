/// Question type requested for AI generation / stored on each item.
enum QuizQuestionType { mcq, trueFalse, shortAnswer, fillBlank, mixed }

/// Difficulty requested for AI generation / stored per question.
enum QuizDifficulty { easy, medium, hard, mixed }

/// How the source text was assembled for generation.
enum QuestionSourceType {
  selectedText,
  page,
  pages,
  material,
  annotations,
  notes,
  annotationsAndNotes,
  aiSummary,
  aiExplanation,
  aiDeepExplanation,
  aiRealWorldExamples,
}

/// Supported quiz play modes. Exam Mode is reserved for a follow-up.
enum QuizPlayMode {
  /// Reveal correctness + explanation after each answer check.
  study,

  /// Reserved: hide correctness until final submit.
  exam,
}

extension QuizQuestionTypeX on QuizQuestionType {
  String get storageValue => switch (this) {
    QuizQuestionType.mcq => 'mcq',
    QuizQuestionType.trueFalse => 'true_false',
    QuizQuestionType.shortAnswer => 'short_answer',
    QuizQuestionType.fillBlank => 'fill_blank',
    QuizQuestionType.mixed => 'mixed',
  };

  String get label => switch (this) {
    QuizQuestionType.mcq => 'Multiple Choice',
    QuizQuestionType.trueFalse => 'True / False',
    QuizQuestionType.shortAnswer => 'Short Answer',
    QuizQuestionType.fillBlank => 'Fill in the Blank',
    QuizQuestionType.mixed => 'Mixed',
  };

  static QuizQuestionType fromStorage(String value) {
    return QuizQuestionType.values.firstWhere(
      (e) => e.storageValue == value,
      orElse: () => QuizQuestionType.mixed,
    );
  }
}

extension QuizDifficultyX on QuizDifficulty {
  String get storageValue => name;

  String get label => switch (this) {
    QuizDifficulty.easy => 'Easy',
    QuizDifficulty.medium => 'Medium',
    QuizDifficulty.hard => 'Hard',
    QuizDifficulty.mixed => 'Mixed',
  };

  static QuizDifficulty fromStorage(String? value) {
    return QuizDifficulty.values.firstWhere(
      (e) => e.name == value,
      orElse: () => QuizDifficulty.mixed,
    );
  }
}

extension QuestionSourceTypeX on QuestionSourceType {
  String get storageValue => switch (this) {
    QuestionSourceType.selectedText => 'selected_text',
    QuestionSourceType.page => 'page',
    QuestionSourceType.pages => 'pages',
    QuestionSourceType.material => 'material',
    QuestionSourceType.annotations => 'annotations',
    QuestionSourceType.notes => 'notes',
    QuestionSourceType.annotationsAndNotes => 'annotations_and_notes',
    QuestionSourceType.aiSummary => 'ai_summary',
    QuestionSourceType.aiExplanation => 'ai_explanation',
    QuestionSourceType.aiDeepExplanation => 'ai_deep_explanation',
    QuestionSourceType.aiRealWorldExamples => 'ai_real_world_examples',
  };

  String get label => switch (this) {
    QuestionSourceType.selectedText => 'Selected text',
    QuestionSourceType.page => 'Current page',
    QuestionSourceType.pages => 'Selected pages',
    QuestionSourceType.material => 'Entire material',
    QuestionSourceType.annotations => 'Annotations',
    QuestionSourceType.notes => 'Notes',
    QuestionSourceType.annotationsAndNotes => 'Annotations + notes',
    QuestionSourceType.aiSummary => 'AI Summary',
    QuestionSourceType.aiExplanation => 'AI Explanation',
    QuestionSourceType.aiDeepExplanation => 'AI Deep Explanation',
    QuestionSourceType.aiRealWorldExamples => 'AI Real-World Examples',
  };

  static QuestionSourceType fromStorage(String value) {
    return QuestionSourceType.values.firstWhere(
      (e) => e.storageValue == value,
      orElse: () => QuestionSourceType.selectedText,
    );
  }
}

/// Allowed question counts in the generation UI.
const kQuizQuestionCounts = [5, 10, 20, 50];

/// A validated AI-generated question (pre-persistence).
class GeneratedQuizQuestion {
  const GeneratedQuizQuestion({
    required this.type,
    required this.question,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    this.options = const [],
    this.sourcePage,
    this.sourceText,
  });

  final QuizQuestionType type;
  final String question;

  /// MCQ: option index (0–3). True/False: `true`/`false`. Others: answer text.
  final Object correctAnswer;
  final String explanation;
  final QuizDifficulty difficulty;
  final List<String> options;
  final int? sourcePage;
  final String? sourceText;

  bool get isMcq => type == QuizQuestionType.mcq;
  bool get isTrueFalse => type == QuizQuestionType.trueFalse;

  String get correctAnswerStorage {
    final value = correctAnswer;
    if (value is bool) return value ? 'true' : 'false';
    return '$value';
  }
}

/// Validated Gemini quiz payload.
class GeneratedQuiz {
  const GeneratedQuiz({required this.title, required this.questions});

  final String title;
  final List<GeneratedQuizQuestion> questions;
}

/// In-memory question with options for quiz play.
class QuizQuestionView {
  const QuizQuestionView({
    required this.id,
    required this.questionSetId,
    required this.type,
    required this.question,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.position,
    required this.options,
    this.sourcePage,
    this.sourceText,
    this.materialId,
  });

  final String id;
  final String questionSetId;
  final QuizQuestionType type;
  final String question;
  final String correctAnswer;
  final String? explanation;
  final QuizDifficulty difficulty;
  final int position;
  final List<QuizOptionView> options;
  final int? sourcePage;
  final String? sourceText;
  final String? materialId;
}

class QuizOptionView {
  const QuizOptionView({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.position,
  });

  final String id;
  final String text;
  final bool isCorrect;
  final int position;
}

/// Aggregated result after submitting / finishing a quiz attempt.
class QuizScore {
  const QuizScore({
    required this.correctCount,
    required this.incorrectCount,
    required this.totalQuestions,
    required this.score,
  });

  final int correctCount;
  final int incorrectCount;
  final int totalQuestions;
  final int score;

  double get percentage =>
      totalQuestions == 0 ? 0 : (correctCount / totalQuestions) * 100;
}

/// Grades a single answer against the stored question.
abstract final class QuizGrader {
  static bool grade({
    required QuizQuestionView question,
    String? selectedOptionId,
    String? answerText,
  }) {
    switch (question.type) {
      case QuizQuestionType.mcq:
        final selected = question.options
            .where((o) => o.id == selectedOptionId)
            .firstOrNull;
        return selected?.isCorrect ?? false;
      case QuizQuestionType.trueFalse:
        final selected = question.options
            .where((o) => o.id == selectedOptionId)
            .firstOrNull;
        if (selected != null) return selected.isCorrect;
        final normalized = (answerText ?? '').trim().toLowerCase();
        final expected = question.correctAnswer.trim().toLowerCase();
        return normalized == expected;
      case QuizQuestionType.shortAnswer:
      case QuizQuestionType.fillBlank:
        return _normalize(answerText) == _normalize(question.correctAnswer);
      case QuizQuestionType.mixed:
        return false;
    }
  }

  static String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
