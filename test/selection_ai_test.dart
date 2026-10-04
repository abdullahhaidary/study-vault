import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_actions.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_models.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_assistant/services/ai_prompt_builder.dart';
import 'package:study_vault/features/ai_assistant/services/annotation_ai_context_builder.dart';
import 'package:study_vault/features/selection_ai/domain/markdown_selection_editor.dart';
import 'package:study_vault/features/selection_ai/domain/selection_ai_host.dart';

const _md = '''
# Project success

Success is **more than finishing**. A completed system that nobody uses is an
output — not a successful organizational change.

- Delivery asks whether the project was managed well.
- System asks whether the product works.

ROI = `(Benefits − Costs) / Costs × 100%`
''';

void main() {
  group('MarkdownSelectionEditor.locate', () {
    test('exact match', () {
      final r = MarkdownSelectionEditor.locate(_md, 'Project success');
      expect(r, isNotNull);
      expect(_md.substring(r!.start, r.end), 'Project success');
    });

    test('tolerates inline emphasis and wrapped lines', () {
      final r = MarkdownSelectionEditor.locate(
        _md,
        'Success is more than finishing. A completed system that nobody uses is an output',
      );
      expect(r, isNotNull);
      final hit = _md.substring(r!.start, r.end);
      expect(hit, startsWith('Success is **more'));
      expect(hit, endsWith('output'));
    });

    test('tolerates inline code markers', () {
      final r = MarkdownSelectionEditor.locate(_md, 'Costs × 100%');
      expect(r, isNotNull);
    });

    test('returns null when text is absent', () {
      expect(MarkdownSelectionEditor.locate(_md, 'not in document'), isNull);
      expect(MarkdownSelectionEditor.locate(_md, '   '), isNull);
    });
  });

  group('MarkdownSelectionEditor apply', () {
    test('replace swaps the passage', () {
      final out = MarkdownSelectionEditor.replace(
        _md,
        'System asks whether the product works.',
        'System asks whether the product is correct.',
      );
      expect(out, contains('product is correct.'));
      expect(out, isNot(contains('product works.')));
    });

    test('insertBelow adds a block after the paragraph', () {
      final out = MarkdownSelectionEditor.insertBelow(
        _md,
        'more than finishing',
        '> Note: adoption matters.',
      )!;
      final idx = out.indexOf('> Note');
      expect(idx, greaterThan(out.indexOf('organizational change.')));
      expect(idx, lessThan(out.indexOf('- Delivery')));
    });

    test('insertBelow at the last block appends', () {
      final out = MarkdownSelectionEditor.insertBelow(
        _md,
        'Costs × 100%',
        'Payback = Investment / Annual benefit',
      )!;
      expect(
        out.trimRight(),
        endsWith('Payback = Investment / Annual benefit'),
      );
    });

    test('append', () {
      expect(MarkdownSelectionEditor.append('', 'x'), 'x');
      expect(MarkdownSelectionEditor.append('a\n', 'b'), 'a\n\nb\n');
    });
  });

  group('AiContextScope', () {
    AiExecutionSelection selection() => AiExecutionSelection.resolve(
      provider: AiProviderId.gemini,
      requestedModelId: '',
      action: AiStudyAction.explain,
    );

    test('host exposes scopes it can serve', () {
      const bare = SelectionAiHost(title: 'x');
      expect(bare.availableScopes, [AiContextScope.selectionOnly]);

      final full = SelectionAiHost(
        title: 'x',
        documentText: 'doc',
        loadSummary: () async => 's',
      );
      expect(full.availableScopes, AiContextScope.values);
    });

    test('withScope sets surrounding text and prompt label', () {
      final base = AnnotationAiContextBuilder.fromTextSelection(
        selectedText: 'nobody uses',
        documentText: _md,
        sourceTitle: 'Summary',
      );
      expect(base.surroundingText, isNotNull);

      final only = AnnotationAiContextBuilder.withScope(
        base,
        scope: AiContextScope.selectionOnly,
      );
      expect(only.surroundingText, isNull);

      final summary = AnnotationAiContextBuilder.withScope(
        base,
        scope: AiContextScope.summary,
        summaryText: 'The summary',
      );
      expect(summary.surroundingText, 'The summary');
      final request = summary.toStudyRequest(
        action: AiStudyAction.explain,
        selection: selection(),
      );
      expect(request.surroundingLabel, 'DOCUMENT SUMMARY');
      expect(
        AiPromptBuilder.materialBlock(request),
        contains('DOCUMENT SUMMARY (clarify meaning only'),
      );
    });

    test('full text is truncated to stay under the hard limit', () {
      final base = AnnotationAiContextBuilder.fromTextSelection(
        selectedText: 'abc',
        documentText: 'abc',
      );
      final big = 'x' * (kAiHardSourceLimit * 2);
      final ctx = AnnotationAiContextBuilder.withScope(
        base,
        scope: AiContextScope.fullText,
        fullText: big,
      );
      expect(
        ctx.surroundingText!.length,
        lessThanOrEqualTo(kAiDocumentContextLimit + 1),
      );
      expect(
        ctx.primaryText.length + ctx.surroundingText!.length,
        lessThan(kAiHardSourceLimit),
      );
    });
  });
}
