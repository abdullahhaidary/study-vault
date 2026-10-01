import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study_pins/data/pin_categories_providers.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../domain/ai_models.dart';
import '../services/markdown_to_quill.dart';

Future<void> showAiAnnotationPreview(
  BuildContext context,
  WidgetRef ref, {
  required AiAnnotationDraft draft,
  required String selectedText,
  Future<void> Function(AiAnnotationDraft draft)? onSave,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AiAnnotationPreviewScreen(
        draft: draft,
        selectedText: selectedText,
        onSave: onSave,
      ),
    ),
  );
}

class AiAnnotationPreviewScreen extends ConsumerStatefulWidget {
  const AiAnnotationPreviewScreen({
    super.key,
    required this.draft,
    required this.selectedText,
    this.onSave,
  });

  final AiAnnotationDraft draft;
  final String selectedText;
  final Future<void> Function(AiAnnotationDraft draft)? onSave;

  @override
  ConsumerState<AiAnnotationPreviewScreen> createState() =>
      _AiAnnotationPreviewScreenState();
}

class _AiAnnotationPreviewScreenState
    extends ConsumerState<AiAnnotationPreviewScreen> {
  late final TextEditingController _short;
  late String _fullMarkdown;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _short = TextEditingController(text: widget.draft.shortDescription);
    _fullMarkdown = widget.draft.fullNoteMarkdown;
    _categoryId = widget.draft.suggestedCategory;
  }

  @override
  void dispose() {
    _short.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(studyPinCategoryMapProvider).valueOrNull ?? const {};
    final stored = MarkdownToQuill.toDeltaJson(_fullMarkdown);

    return Scaffold(
      appBar: AppBar(title: const Text('Annotation draft')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Selected text', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(widget.selectedText),
          const SizedBox(height: 16),
          TextField(
            controller: _short,
            decoration: const InputDecoration(
              labelText: 'Short Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final c in categories.values)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Full Note', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final edited = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => FullExplanationScreen(
                        initialText: stored,
                        title: 'Edit Full Note',
                      ),
                    ),
                  );
                  if (edited != null) {
                    setState(() {
                      // Keep as stored quill; convert back to markdown-ish plain for draft model.
                      _fullMarkdown = StudyNoteCodec.plainTextPreview(edited);
                      // Prefer keeping quill JSON as markdown body for save path:
                      // We pass markdown to onSave — convert stored rich via plain is lossy.
                      // Better: store delta JSON in fullNoteMarkdown field when it is delta.
                      if (StudyNoteCodec.isRichDeltaJson(edited)) {
                        _fullMarkdown = edited;
                      }
                    });
                  }
                },
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StudyRichTextViewer(
                storedValue: StudyNoteCodec.isRichDeltaJson(_fullMarkdown)
                    ? _fullMarkdown
                    : MarkdownToQuill.toDeltaJson(_fullMarkdown),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final short = _short.text.trim();
                        if (short.isEmpty) return;
                        setState(() => _saving = true);
                        final fullStored =
                            StudyNoteCodec.isRichDeltaJson(_fullMarkdown)
                            ? _fullMarkdown
                            : MarkdownToQuill.toDeltaJson(_fullMarkdown);
                        final draft = AiAnnotationDraft(
                          shortDescription: short,
                          fullNoteMarkdown: fullStored,
                          suggestedCategory: _categoryId,
                        );
                        await widget.onSave?.call(draft);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Save Study Pin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
