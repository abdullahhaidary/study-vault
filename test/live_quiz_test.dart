import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_questions/domain/live_quiz_models.dart';
import 'package:study_vault/features/ai_questions/domain/question_source.dart';
import 'package:study_vault/features/ai_questions/services/live_quiz_service.dart';

import 'helpers/ai_selection_helpers.dart';

class _FakeLiveQuizClient implements LiveQuizCompletionClient {
  _FakeLiveQuizClient(this.replies);

  final List<String> replies;
  final sent = <List<Map<String, String>>>[];

  @override
  Future<String> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) async {
    sent.add(messages);
    if (replies.isEmpty) {
      throw const AiEmptyResultException();
    }
    return replies.removeAt(0);
  }
}

QuestionSource _source([String text = 'Gradient descent minimizes a loss.']) {
  return QuestionSourceBuilder.fromSelectedText(text: text);
}

void main() {
  group('LiveQuizAskResult.parse', () {
    test('reads a question', () {
      final result = LiveQuizAskResult.parse('{"question":"What is descent?"}');
      expect(result.question, 'What is descent?');
    });

    test('accepts a fenced JSON body', () {
      final result = LiveQuizAskResult.parse(
        '```json\n{"question":"Why minimize loss?"}\n```',
      );
      expect(result.question, 'Why minimize loss?');
    });

    test('empty question throws', () {
      expect(
        () => LiveQuizAskResult.parse('{"question":"  "}'),
        throwsA(isA<AiEmptyResultException>()),
      );
    });

    test('malformed JSON throws', () {
      expect(
        () => LiveQuizAskResult.parse('not json'),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });
  });

  group('LiveQuizJudgeResult.parse', () {
    test('correct requires nextQuestion', () {
      final result = LiveQuizJudgeResult.parse(
        '{"correct":true,"feedback":"Yes.","nextQuestion":"When is it used?"}',
      );
      expect(result.correct, isTrue);
      expect(result.feedback, 'Yes.');
      expect(result.nextQuestion, 'When is it used?');
    });

    test('wrong drops nextQuestion until Understood', () {
      final result = LiveQuizJudgeResult.parse(
        '{"correct":false,"feedback":"From the source: step size matters.",'
        '"nextQuestion":"Should not appear yet"}',
      );
      expect(result.correct, isFalse);
      expect(result.feedback, 'From the source: step size matters.');
      expect(result.nextQuestion, isNull);
    });

    test('correct without nextQuestion throws', () {
      expect(
        () => LiveQuizJudgeResult.parse('{"correct":true,"feedback":"Yes."}'),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });

    test('missing feedback throws', () {
      expect(
        () => LiveQuizJudgeResult.parse('{"correct":false,"feedback":""}'),
        throwsA(isA<AiMalformedOutputException>()),
      );
    });
  });

  group('LiveQuizService', () {
    late MemoryAiSettingsStore settings;

    setUp(() {
      settings = MemoryAiSettingsStore();
    });

    test('start asks one question', () async {
      final client = _FakeLiveQuizClient([
        '{"question":"What does gradient descent minimize?"}',
      ]);
      final service = LiveQuizService(client: client, settings: settings);
      final session = await service.start(
        source: _source(),
        selection: testGeminiSelection(),
      );
      expect(session.phase, LiveQuizPhase.awaitingAnswer);
      expect(session.question, 'What does gradient descent minimize?');
      expect(session.canSubmit, isTrue);
      expect(client.sent.single.first['role'], 'system');
      expect(client.sent.single.last['content'], contains('STUDY MATERIAL'));
    });

    test('wrong answer stays on feedback until Understood', () async {
      final client = _FakeLiveQuizClient([
        '{"question":"What is minimized?"}',
        '{"correct":false,"feedback":"The source says the loss is minimized."}',
        '{"question":"Why take a step opposite the gradient?"}',
      ]);
      final service = LiveQuizService(client: client, settings: settings);
      final session = await service.start(
        source: _source(),
        selection: testGeminiSelection(),
      );

      await service.submitAnswer(session: session, answer: 'accuracy');
      expect(session.phase, LiveQuizPhase.feedbackWrong);
      expect(session.canContinueAfterWrong, isTrue);
      expect(session.question, 'What is minimized?');
      expect(session.lastFeedback, contains('loss is minimized'));
      expect(
        () => service.submitAnswer(session: session, answer: 'loss'),
        throwsA(isA<AiMalformedOutputException>()),
      );

      await service.continueAfterUnderstood(session: session);
      expect(session.phase, LiveQuizPhase.awaitingAnswer);
      expect(session.question, 'Why take a step opposite the gradient?');
      expect(session.lastFeedback, isNull);
      expect(session.history, hasLength(1));
      expect(session.history.single.correct, isFalse);
    });

    test('correct answer surfaces the next question immediately', () async {
      final client = _FakeLiveQuizClient([
        '{"question":"What is minimized?"}',
        '{"correct":true,"feedback":"Right — the loss.",'
            '"nextQuestion":"What does the learning rate control?"}',
      ]);
      final service = LiveQuizService(client: client, settings: settings);
      final session = await service.start(
        source: _source(),
        selection: testGeminiSelection(),
      );

      await service.submitAnswer(session: session, answer: 'the loss');
      expect(session.phase, LiveQuizPhase.awaitingAnswer);
      expect(session.lastWasCorrect, isTrue);
      expect(session.question, 'What does the learning rate control?');
      expect(session.history.single.correct, isTrue);
      expect(session.canContinueAfterWrong, isFalse);
      expect(client.sent, hasLength(2));
    });

    test('empty source and empty AI output throw', () async {
      final service = LiveQuizService(
        client: _FakeLiveQuizClient(const []),
        settings: settings,
      );
      expect(
        () => service.start(
          source: QuestionSourceBuilder.fromSelectedText(text: '   '),
          selection: testGeminiSelection(),
        ),
        throwsA(isA<AiMalformedOutputException>()),
      );

      final emptyClient = _FakeLiveQuizClient(['   ']);
      final emptyService = LiveQuizService(
        client: emptyClient,
        settings: settings,
      );
      expect(
        () => emptyService.start(
          source: _source(),
          selection: testGeminiSelection(),
        ),
        throwsA(isA<AiEmptyResultException>()),
      );
    });
  });
}
