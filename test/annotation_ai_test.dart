import 'package:flutter_test/flutter_test.dart';
import 'helpers/ai_selection_helpers.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_exceptions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/annotation_ai_context.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_context_builder.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/fake_ai_service.dart';
import 'package:study_vault/features/ai_assistant/services/surrounding_text_extractor.dart';
import 'package:study_vault/core/text/text_direction_utils.dart';
import 'package:flutter/painting.dart';

void main() {
  group('SurroundingTextExtractor', () {
    test('marks selected text and keeps neighbors', () {
      const page =
          'Alpha paragraph one.\n\n'
          'Gradient descent updates weights using the gradient of the loss.\n\n'
          'Omega paragraph three.';
      const selected =
          'Gradient descent updates weights using the gradient of the loss.';

      final surrounding = SurroundingTextExtractor.extract(
        pageText: page,
        selectedText: selected,
      );

      expect(surrounding, isNotNull);
      expect(surrounding!, contains('>>> SELECTED <<<'));
      expect(surrounding, contains(selected));
      expect(surrounding, contains('BEFORE:'));
      expect(surrounding, contains('AFTER:'));
      expect(surrounding, contains('Alpha'));
      expect(surrounding, contains('Omega'));
    });

    test('returns null for empty selection', () {
      expect(
        SurroundingTextExtractor.extract(
          pageText: 'Some page text',
          selectedText: '   ',
        ),
        isNull,
      );
    });

    test('caps oversized windows', () {
      final before = 'B' * 2000;
      final selected = 'SELECTED_CORE';
      final after = 'A' * 2000;
      final page = '$before$selected$after';
      final surrounding = SurroundingTextExtractor.extract(
        pageText: page,
        selectedText: selected,
        maxTotal: 800,
      );
      expect(surrounding, isNotNull);
      expect(surrounding!.length, lessThanOrEqualTo(900));
      expect(surrounding, contains(selected));
    });
  });

  group('AnnotationAiContextBuilder', () {
    test('builds pdf selection context with surrounding text', () {
      final ctx = AnnotationAiContextBuilder.fromPdfSelection(
        selectedText: 'learning rate',
        materialId: 'mat-1',
        lessonId: 'les-1',
        pageNumber: 12,
        pageText:
            'Intro.\n\nThe learning rate controls step size.\n\nConclusion.',
      );

      expect(ctx.selectedText, 'learning rate');
      expect(ctx.materialId, 'mat-1');
      expect(ctx.lessonId, 'les-1');
      expect(ctx.pageNumber, 12);
      expect(ctx.surroundingText, isNotNull);
      expect(ctx.surroundingText!, contains('SELECTED'));
      expect(ctx.hasUsableText, isTrue);
    });

    test('builds pin context from annotation body', () {
      final ctx = AnnotationAiContextBuilder.fromStudyPin(
        pinId: 'pin-1',
        shortText: 'Cost function',
        fullExplanationStored: '[{"insert":"J(θ) measures error\\n"}]',
        selectedText: '',
        materialId: 'mat-1',
        pageNumber: 3,
      );

      expect(ctx.annotationId, 'pin-1');
      expect(ctx.primaryText, contains('Cost function'));
      expect(ctx.shortDescription, 'Cost function');
    });
  });

  group('AiPromptBuilder annotation prompts', () {
    AiStudyRequest base(AiStudyAction action, {String? custom}) {
      return AiStudyRequest(
        selection: testGeminiSelection(),
        action: action,
        sourceText: 'Gradient descent updates weights.',
        selectedText: 'Gradient descent updates weights.',
        surroundingText: 'BEFORE:\nIntro\n\nAFTER:\nNext idea',
        pageNumber: 12,
        language: AiLanguage.english,
        customPrompt: custom,
      );
    }

    test('explain includes selected + surrounding + page', () {
      final prompt = AiPromptBuilder.explainText(base(AiStudyAction.explain));
      expect(prompt, contains('university student'));
      expect(prompt, contains('SELECTED TEXT:'));
      expect(prompt, contains('SURROUNDING CONTEXT'));
      expect(prompt, contains('PAGE: 12'));
      expect(prompt, contains('Do not invent unsupported facts'));
    });

    test('simplify / summarize / define / example specialize tasks', () {
      expect(
        AiPromptBuilder.simplifyText(base(AiStudyAction.simplify)),
        contains('simpler language'),
      );
      expect(
        AiPromptBuilder.summarizeText(base(AiStudyAction.summarize)),
        contains('important ideas'),
      );
      expect(
        AiPromptBuilder.defineText(base(AiStudyAction.define)),
        contains('meaning in this context'),
      );
      expect(
        AiPromptBuilder.giveExample(base(AiStudyAction.giveExample)),
        contains('one or two examples'),
      );
    });

    test('custom and ask prompts include user instruction', () {
      final ask = AiPromptBuilder.askAboutSelection(
        base(AiStudyAction.askAi, custom: 'Why is this important?'),
      );
      expect(ask, contains('STUDENT QUESTION:'));
      expect(ask, contains('Why is this important?'));

      final custom = AiPromptBuilder.customPrompt(
        base(
          AiStudyAction.customPrompt,
          custom: 'Explain using a banking example.',
        ),
      );
      expect(custom, contains('CUSTOM INSTRUCTION:'));
      expect(custom, contains('banking example'));
    });

    test('translate preserves technical terms instruction', () {
      final prompt = AiPromptBuilder.translateText(
        base(
          AiStudyAction.translate,
        ).copyWith(translateTarget: AiLanguage.persianDari),
      );
      expect(prompt, contains('Persian/Dari'));
      expect(prompt, contains('technical'));
    });

    test('persian language mode preserved', () {
      final prompt = AiPromptBuilder.explainText(
        base(AiStudyAction.explain).copyWith(language: AiLanguage.persianDari),
      );
      expect(prompt, contains('Persian/Dari'));
    });
  });

  group('AnnotationAiService', () {
    test('rejects empty selection', () async {
      final service = AnnotationAiService(aiService: FakeAiService());
      expect(
        () => service.run(
          context: const AnnotationAiContext(selectedText: '  '),
          action: AiStudyAction.explain,
          selection: testGeminiSelection(),
        ),
        throwsA(isA<AiEmptySelectionException>()),
      );
    });

    test('rejects oversized selection', () async {
      final service = AnnotationAiService(aiService: FakeAiService());
      final huge = 'x' * (kAiHardSourceLimit + 10);
      expect(
        () => service.run(
          context: AnnotationAiContext(selectedText: huge),
          action: AiStudyAction.explain,
          selection: testGeminiSelection(),
        ),
        throwsA(isA<AiSourceTooLargeException>()),
      );
    });

    test('runs explain via fake provider and caches', () async {
      var calls = 0;
      final fake = FakeAiService(
        handler: (request) async {
          calls++;
          return AiTextResult(markdown: 'ok ${request.sourceText}');
        },
      );
      final service = AnnotationAiService(aiService: fake);
      const ctx = AnnotationAiContext(
        selectedText: 'Gradient descent',
        pageNumber: 2,
      );

      final first = await service.run(
        context: ctx,
        action: AiStudyAction.explain,
      selection: testGeminiSelection(),
      );
      final second = await service.run(
        context: ctx,
        action: AiStudyAction.explain,
        selection: testGeminiSelection(),
      );

      expect(first, isA<AiTextResult>());
      expect(second, isA<AiTextResult>());
      expect(calls, 1);
    });

    test('ask AI is not cached', () async {
      var calls = 0;
      final fake = FakeAiService(
        handler: (request) async {
          calls++;
          return const AiTextResult(markdown: 'answer');
        },
      );
      final service = AnnotationAiService(aiService: fake);
      const ctx = AnnotationAiContext(selectedText: 'θ');

      await service.run(
        context: ctx,
        action: AiStudyAction.askAi,
      selection: testGeminiSelection(),
        customPrompt: 'What is this?',
      );
      await service.run(
        context: ctx,
        action: AiStudyAction.askAi,
        selection: testGeminiSelection(),
        customPrompt: 'What is this?',
      );
      expect(calls, 2);
    });

    test('flashcard generation integration', () async {
      final service = AnnotationAiService(aiService: FakeAiService());
      final result = await service.run(
        context: const AnnotationAiContext(
          selectedText: 'Learning rate α controls step size.',
        ),
        action: AiStudyAction.generateFlashcards,
        selection: testGeminiSelection(),
        flashcardCount: 5,
      );
      expect(result, isA<AiFlashcardsResult>());
      expect((result as AiFlashcardsResult).cards, hasLength(5));
    });

    test('follow-up keeps annotation context', () async {
      AiStudyRequest? seen;
      final fake = FakeAiService(
        handler: (request) async {
          seen = request;
          return const AiTextResult(markdown: 'simpler');
        },
      );
      final service = AnnotationAiService(aiService: fake);
      const ctx = AnnotationAiContext(
        selectedText: 'Gradient descent',
        surroundingText: 'BEFORE:\nML intro',
        pageNumber: 4,
      );

      await service.followUp(
      selection: testGeminiSelection(),
      context: ctx,
        conversation: const [
          AiConversationTurn(
            userMessage: 'Explain',
            assistantMarkdown: 'Long explanation',
          ),
        ],
        userMessage: 'Make it simpler.',
      );

      expect(seen, isNotNull);
      expect(seen!.action, AiStudyAction.askAi);
      expect(seen!.customPrompt, 'Make it simpler.');
      expect(seen!.surroundingText, contains('ML intro'));
      expect(seen!.pageNumber, 4);
      expect(seen!.conversation, isNotEmpty);
    });
  });

  group('RTL / language', () {
    test('resolves Persian selection as RTL', () {
      expect(
        TextDirectionUtils.resolve('گرادیان نزول برای بهینه‌سازی'),
        TextDirection.rtl,
      );
    });

    test('context builder sets RTL direction for Persian', () {
      final ctx = AnnotationAiContextBuilder.fromPdfSelection(
        selectedText: 'نرخ یادگیری',
        pageText: 'متن فارسی درباره نرخ یادگیری در اینجا است.',
      );
      expect(ctx.direction, TextDirection.rtl);
    });
  });

  group('source page preservation', () {
    test('toStudyRequest keeps page and material ids', () {
      const ctx = AnnotationAiContext(
        selectedText: 'precision',
        materialId: 'm1',
        lessonId: 'l1',
        annotationId: 'a1',
        pageNumber: 9,
        surroundingText: 'ctx',
      );
      final req = ctx.toStudyRequest(
        action: AiStudyAction.define,
        selection: testGeminiSelection(),
      );
      expect(req.pageNumber, 9);
      expect(req.materialId, 'm1');
      expect(req.lessonId, 'l1');
      expect(req.annotationId, 'a1');
      expect(req.surroundingText, 'ctx');
    });
  });
}
