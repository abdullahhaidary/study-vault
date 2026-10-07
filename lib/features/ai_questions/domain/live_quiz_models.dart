import 'dart:convert';

import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import 'question_source.dart';

enum LiveQuizPhase {
  asking,
  awaitingAnswer,
  feedbackWrong,
  feedbackCorrect,
  ended,
}

class LiveQuizExchange {
  const LiveQuizExchange({
    required this.question,
    required this.answer,
    required this.correct,
    required this.feedback,
  });

  final String question;
  final String answer;
  final bool correct;
  final String feedback;
}

class LiveQuizAskResult {
  const LiveQuizAskResult({required this.question});

  final String question;

  static LiveQuizAskResult parse(String raw) {
    final map = _decodeObject(raw);
    final question = (map['question'] as String?)?.trim() ?? '';
    if (question.isEmpty) {
      throw const AiEmptyResultException(
        'The AI did not return a question. Please try again.',
      );
    }
    return LiveQuizAskResult(question: question);
  }
}

class LiveQuizJudgeResult {
  const LiveQuizJudgeResult({
    required this.correct,
    required this.feedback,
    this.nextQuestion,
  });

  final bool correct;
  final String feedback;
  final String? nextQuestion;

  static LiveQuizJudgeResult parse(String raw) {
    final map = _decodeObject(raw);
    final correct = map['correct'];
    if (correct is! bool) {
      throw const AiMalformedOutputException(
        'The AI did not say whether the answer was correct.',
      );
    }
    final feedback = (map['feedback'] as String?)?.trim() ?? '';
    if (feedback.isEmpty) {
      throw const AiMalformedOutputException(
        'The AI did not return feedback for this answer.',
      );
    }
    final next = (map['nextQuestion'] as String?)?.trim();
    if (correct && (next == null || next.isEmpty)) {
      throw const AiMalformedOutputException(
        'The AI marked the answer correct but did not ask the next question.',
      );
    }
    return LiveQuizJudgeResult(
      correct: correct,
      feedback: feedback,
      nextQuestion: correct ? next : null,
    );
  }
}

class LiveQuizSession {
  LiveQuizSession({
    required this.source,
    required this.selection,
    required this.question,
    this.phase = LiveQuizPhase.awaitingAnswer,
    this.lastFeedback,
    this.lastWasCorrect,
  });

  final QuestionSource source;
  final AiExecutionSelection selection;
  LiveQuizPhase phase;
  String question;
  String? lastFeedback;
  bool? lastWasCorrect;
  final List<LiveQuizExchange> history = [];

  int get questionNumber => phase == LiveQuizPhase.feedbackWrong
      ? history.length
      : history.length + 1;

  bool get canSubmit => phase == LiveQuizPhase.awaitingAnswer;

  bool get canContinueAfterWrong => phase == LiveQuizPhase.feedbackWrong;
}

Map<String, dynamic> _decodeObject(String raw) {
  final cleaned = _stripCodeFence(raw.trim());
  if (cleaned.isEmpty) throw const AiEmptyResultException();
  try {
    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const AiMalformedOutputException();
  } on AiException {
    rethrow;
  } on Object {
    throw const AiMalformedOutputException();
  }
}

String _stripCodeFence(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    t = t.replaceFirst(RegExp(r'^```(?:json|markdown|md)?\s*'), '');
    if (t.endsWith('```')) {
      t = t.substring(0, t.length - 3).trim();
    }
  }
  return t.trim();
}
