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
      AiStudyAction.fixGrammar =>
        AiTextResult(markdown: 'Simplified: ${request.sourceText}'),
      AiStudyAction.organize => AiTextResult(
        markdown:
            '# Organized Notes\n\n## Summary\n\n'
            '- ${request.sourceText.split('\n').first}\n',
      ),
      AiStudyAction.summarize => AiTextResult(
        markdown: '- Key point from source text',
      ),
      AiStudyAction.createAnnotation => AiAnnotationDraft(
        shortDescription: 'AI Draft',
        fullNoteMarkdown: '## Note\n\n${request.sourceText}',
        suggestedCategory: categoryNameToId['Definition'],
      ),
      AiStudyAction.generateFlashcards => AiFlashcardsResult(
        cards: List.generate(
          request.flashcardCount.clamp(1, 10),
          (i) => AiFlashcardDraft(
            front: 'Q${i + 1} from study text?',
            back: 'A${i + 1}',
          ),
        ),
      ),
      AiStudyAction.generateQuestions => const AiQuestionsResult(
        questions: [
          AiQuestionDraft(
            question: 'What is the main idea?',
            answer: 'See the source text.',
          ),
        ],
      ),
    };
  }
}
