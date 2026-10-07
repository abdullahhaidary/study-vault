import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_style_memory.dart';
import '../../ai_assistant/services/deepseek_ai_service.dart';
import '../../ai_assistant/services/gemini_ai_service.dart';
import '../../ai_assistant/services/new_api_claude_service.dart';
import '../domain/live_quiz_models.dart';
import '../domain/question_source.dart';
import '../domain/quiz_models.dart';

abstract interface class LiveQuizCompletionClient {
  Future<String> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  });
}

class RoutingLiveQuizCompletionClient implements LiveQuizCompletionClient {
  RoutingLiveQuizCompletionClient({
    required this._gemini,
    required this._deepSeek,
    this._newApi,
  });

  final GeminiAiService _gemini;
  final DeepSeekAiService _deepSeek;
  final NewApiClaudeService? _newApi;

  @override
  Future<String> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) async {
    final result = switch (selection.provider) {
      AiProviderId.gemini => await _gemini.completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
        timeout: const Duration(seconds: 90),
      ),
      AiProviderId.deepseek => await _deepSeek.completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
        timeout: const Duration(seconds: 90),
      ),
      AiProviderId.newApi => await _requireNewApi().completeDocumentMessages(
        messages: messages,
        maxOutputTokens: maxOutputTokens,
        selection: selection,
        timeout: const Duration(seconds: 90),
      ),
    };
    return result.markdown;
  }

  NewApiClaudeService _requireNewApi() {
    final client = _newApi;
    if (client == null) {
      throw const AiNotConfiguredException('New API is not configured.');
    }
    return client;
  }
}

/// One-question-at-a-time tutor. Each turn is a fresh AI call; the session
/// stays in memory.
class LiveQuizService {
  LiveQuizService({required this.client, required this.settings});

  final LiveQuizCompletionClient client;
  final AiSettingsStore settings;

  static const sourceCharLimit = 24000;
  static const historyLimit = 8;
  static const askMaxTokens = 1024;
  static const judgeMaxTokens = 2048;

  static const _systemRules =
      'You are Study Vault AI quizzing a university student.\n'
      'Ground every question and every wrong-answer explanation in the attached '
      'study material only.\n'
      'Ask topic, scenario, or how-it-works questions. Do not ask trivia such as '
      'year, author, or who created the source.\n'
      'Never leak the answer, an answer key, or a giveaway hint inside a question.\n'
      'Return JSON only. No markdown fences unless the JSON itself needs them.';

  Future<LiveQuizSession> start({
    required QuestionSource source,
    required AiExecutionSelection selection,
  }) async {
    if (source.isEmpty) {
      throw const AiMalformedOutputException(
        'No study content available for this source.',
      );
    }
    final session = LiveQuizSession(
      source: source,
      selection: selection,
      question: '',
      phase: LiveQuizPhase.asking,
    );
    session.question = await _askNext(session);
    session.phase = LiveQuizPhase.awaitingAnswer;
    return session;
  }

  Future<LiveQuizSession> submitAnswer({
    required LiveQuizSession session,
    required String answer,
  }) async {
    if (session.phase != LiveQuizPhase.awaitingAnswer) {
      throw const AiMalformedOutputException(
        'Answer this question before continuing.',
      );
    }
    final trimmed = answer.trim();
    if (trimmed.isEmpty) {
      throw const AiMalformedOutputException('Enter an answer first.');
    }

    session.phase = LiveQuizPhase.asking;
    final judged = LiveQuizJudgeResult.parse(
      await _complete(
        session: session,
        maxOutputTokens: judgeMaxTokens,
        user: _judgeUserPrompt(session, trimmed),
      ),
    );

    session.history.add(
      LiveQuizExchange(
        question: session.question,
        answer: trimmed,
        correct: judged.correct,
        feedback: judged.feedback,
      ),
    );
    session.lastFeedback = judged.feedback;
    session.lastWasCorrect = judged.correct;

    if (judged.correct) {
      session.question = judged.nextQuestion!;
      session.phase = LiveQuizPhase.awaitingAnswer;
    } else {
      session.phase = LiveQuizPhase.feedbackWrong;
    }
    return session;
  }

  Future<LiveQuizSession> continueAfterUnderstood({
    required LiveQuizSession session,
  }) async {
    if (session.phase != LiveQuizPhase.feedbackWrong) {
      throw const AiMalformedOutputException(
        'Confirm you understood the feedback first.',
      );
    }
    session.phase = LiveQuizPhase.asking;
    session.question = await _askNext(session);
    session.lastFeedback = null;
    session.lastWasCorrect = null;
    session.phase = LiveQuizPhase.awaitingAnswer;
    return session;
  }

  void end(LiveQuizSession session) {
    session.phase = LiveQuizPhase.ended;
  }

  Future<String> _askNext(LiveQuizSession session) async {
    final asked = LiveQuizAskResult.parse(
      await _complete(
        session: session,
        maxOutputTokens: askMaxTokens,
        user: _askUserPrompt(session),
      ),
    );
    return asked.question;
  }

  Future<String> _complete({
    required LiveQuizSession session,
    required int maxOutputTokens,
    required String user,
  }) async {
    final preference = await settings.styleForSend(
      provider: session.selection.provider,
    );
    final system = AiStyleMemory.appendToSystem(_systemRules, preference);
    return client.complete(
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      maxOutputTokens: maxOutputTokens,
      selection: session.selection,
    );
  }

  String _askUserPrompt(LiveQuizSession session) {
    final buffer = StringBuffer()
      ..writeln('Ask exactly one new question from the study material.')
      ..writeln('Return JSON only: {"question":"..."}')
      ..writeln()
      ..writeln(_sourceBlock(session.source))
      ..writeln()
      ..writeln(_historyBlock(session.history));
    if (session.history.isNotEmpty) {
      buffer.writeln(
        'Do not repeat an earlier question. Cover a different idea.',
      );
    }
    return buffer.toString().trim();
  }

  String _judgeUserPrompt(LiveQuizSession session, String answer) {
    return '''
Grade this answer using only the study material.

Return JSON only:
{"correct":true|false,"feedback":"...","nextQuestion":"..."}

Rules:
- correct is true when the answer is substantially right.
- feedback must be a full, source-grounded explanation when the answer is wrong.
- feedback may be a short confirmation when the answer is correct.
- Include nextQuestion only when correct. It must be one new question with no answer leaked.

${_sourceBlock(session.source)}

QUESTION:
${session.question}

STUDENT ANSWER:
$answer

${_historyBlock(session.history)}
'''
        .trim();
  }

  String _sourceBlock(QuestionSource source) {
    final label = source.referenceLabel ?? source.type.label;
    final text = _clip(source.text, sourceCharLimit);
    return 'STUDY MATERIAL ($label):\n$text';
  }

  String _historyBlock(List<LiveQuizExchange> history) {
    if (history.isEmpty) return 'PREVIOUS TURNS:\n(none)';
    final recent = history.length <= historyLimit
        ? history
        : history.sublist(history.length - historyLimit);
    final buffer = StringBuffer('PREVIOUS TURNS:');
    for (final turn in recent) {
      buffer
        ..writeln()
        ..writeln('Q: ${turn.question}')
        ..writeln('A: ${turn.answer}')
        ..writeln(turn.correct ? 'Result: correct' : 'Result: wrong');
    }
    return buffer.toString().trim();
  }

  static String _clip(String text, int cap) {
    if (text.length <= cap) return text;
    return '${text.substring(0, cap).trimRight()}…';
  }
}
