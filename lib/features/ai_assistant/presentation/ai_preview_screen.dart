import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/widgets/auto_direction_text.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../domain/ai_models.dart';
import '../services/markdown_to_quill.dart';
import 'widgets/ai_usage_indicator.dart';

enum AiPreviewApplyAction { replace, insertBelow, copy, cancel }

class AiTextPreviewResult {
  const AiTextPreviewResult({
    required this.action,
    required this.markdown,
    required this.storedRich,
  });

  final AiPreviewApplyAction action;
  final String markdown;
  final String storedRich;
}

/// Before/after preview for text transforms. Never auto-saves.
Future<AiTextPreviewResult?> showAiTextPreview(
  BuildContext context, {
  required String originalText,
  required AiTextResult result,
  bool allowReplace = true,
  bool allowInsertBelow = true,
}) {
  return Navigator.of(context).push<AiTextPreviewResult>(
    MaterialPageRoute(
      builder: (_) => AiTextPreviewScreen(
        originalText: originalText,
        result: result,
        allowReplace: allowReplace,
        allowInsertBelow: allowInsertBelow,
      ),
    ),
  );
}

class AiTextPreviewScreen extends StatelessWidget {
  const AiTextPreviewScreen({
    super.key,
    required this.originalText,
    required this.result,
    this.allowReplace = true,
    this.allowInsertBelow = true,
  });

  final String originalText;
  final AiTextResult result;
  final bool allowReplace;
  final bool allowInsertBelow;

  @override
  Widget build(BuildContext context) {
    final stored = MarkdownToQuill.toDeltaJson(result.markdown);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    Widget originalPane() => _Pane(
      title: 'Original',
      child: AutoDirectionSelectableText(originalText),
    );
    Widget aiPane() => _Pane(
      title: 'AI Version',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudyRichTextViewer(storedValue: stored),
          if (result.usage != null && result.usage!.hasAnyMetric) ...[
            const SizedBox(height: 8),
            AiUsageIndicator(usage: result.usage!),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: result.markdown.trim().isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: result.markdown),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Copied')));
                      }
                    },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy response'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(child: originalPane()),
                        const SizedBox(width: 12),
                        Expanded(child: aiPane()),
                      ],
                    )
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Original'),
                              Tab(text: 'AI Version'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [originalPane(), aiPane()],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    AiTextPreviewResult(
                      action: AiPreviewApplyAction.cancel,
                      markdown: result.markdown,
                      storedRich: stored,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    AiTextPreviewResult(
                      action: AiPreviewApplyAction.copy,
                      markdown: result.markdown,
                      storedRich: stored,
                    ),
                  ),
                  child: const Text('Copy'),
                ),
                if (allowInsertBelow)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      AiTextPreviewResult(
                        action: AiPreviewApplyAction.insertBelow,
                        markdown: result.markdown,
                        storedRich: stored,
                      ),
                    ),
                    child: const Text('Insert Below'),
                  ),
                if (allowReplace)
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      AiTextPreviewResult(
                        action: AiPreviewApplyAction.replace,
                        markdown: result.markdown,
                        storedRich: stored,
                      ),
                    ),
                    child: const Text('Replace'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Expanded(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Applies preview result to a QuillController when possible (keeps undo).
void applyPreviewToQuill(
  QuillController controller,
  AiTextPreviewResult preview, {
  required bool hadSelection,
}) {
  if (preview.action == AiPreviewApplyAction.cancel ||
      preview.action == AiPreviewApplyAction.copy) {
    return;
  }
  final doc = StudyNoteCodec.decode(preview.storedRich);
  final plain = doc.toPlainText();
  if (preview.action == AiPreviewApplyAction.replace) {
    if (hadSelection && !controller.selection.isCollapsed) {
      final sel = controller.selection;
      controller.replaceText(
        sel.start,
        sel.end - sel.start,
        plain.trimRight(),
        TextSelection.collapsed(offset: sel.start + plain.trimRight().length),
      );
    } else {
      controller.document = doc;
      controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
    }
  } else if (preview.action == AiPreviewApplyAction.insertBelow) {
    final end = controller.document.length;
    controller.replaceText(
      end - 1,
      0,
      '\n${plain.trimRight()}\n',
      TextSelection.collapsed(offset: end),
    );
  }
}
