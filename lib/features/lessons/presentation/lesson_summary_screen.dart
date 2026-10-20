import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_assistant/services/quill_to_markdown.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/lesson_summary_repository.dart';
import '../domain/lesson_summary.dart';

class LessonSummaryArgs {
  const LessonSummaryArgs({required this.lessonId, required this.lessonName});

  final String lessonId;
  final String lessonName;
}

/// One editable summary per lesson. New AI Summaries of the lesson's
/// documents are appended to it automatically.
class LessonSummaryScreen extends ConsumerStatefulWidget {
  const LessonSummaryScreen({super.key, required this.args});

  final LessonSummaryArgs args;

  static Future<void> open(
    BuildContext context, {
    required String lessonId,
    required String lessonName,
  }) => Navigator.of(context).pushNamed(
    AppRoutes.lessonSummary,
    arguments: LessonSummaryArgs(lessonId: lessonId, lessonName: lessonName),
  );

  @override
  ConsumerState<LessonSummaryScreen> createState() =>
      _LessonSummaryScreenState();
}

class _LessonSummaryScreenState extends ConsumerState<LessonSummaryScreen> {
  String get _lessonId => widget.args.lessonId;

  @override
  void initState() {
    super.initState();
    ref.read(lessonSummaryRepositoryProvider).ensure(_lessonId);
  }

  Future<void> _add() async {
    final markdown = await showAddToLessonSummaryDialog(context);
    if (markdown == null) return;
    await ref
        .read(lessonSummaryRepositoryProvider)
        .appendMarkdown(lessonId: _lessonId, markdown: markdown);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to the summary.')));
  }

  Future<void> _edit() async {
    final note = await ref
        .read(lessonSummaryRepositoryProvider)
        .ensure(_lessonId);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.noteEditor, arguments: note.id);
  }

  Future<void> _clear() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Clear summary?',
      message:
          'All text in this lesson summary will be removed. AI Summaries '
          'saved on each PDF are kept.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await ref.read(lessonSummaryRepositoryProvider).clear(_lessonId);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(lessonSummaryProvider(_lessonId));
    final content = summary.valueOrNull?.content;
    final hasContent = StudyNoteCodec.hasContent(content);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${LessonSummary.title} · ${widget.args.lessonName}'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: hasContent
                ? () => copyLessonSummary(context, ref, lessonId: _lessonId)
                : null,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'clear') _clear();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                enabled: hasContent,
                child: Text(
                  'Clear summary',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.playlist_add),
        label: const Text('Add text / JSON'),
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load the summary: $error')),
        data: (note) => !hasContent
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'No summary yet.\n\nGenerate an AI Summary for a PDF in '
                    'this lesson, or tap "Add text / JSON" to paste one. '
                    'Everything is collected here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : ScrollEdgeArrows(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    96,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: AppSpacing.contentWidth(context),
                        ),
                        child: StudyRichTextViewer(storedValue: note!.content),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Copies the whole lesson summary as Markdown.
Future<void> copyLessonSummary(
  BuildContext context,
  WidgetRef ref, {
  required String lessonId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final note = await ref.read(lessonSummaryRepositoryProvider).ensure(lessonId);
  final markdown = QuillToMarkdown.fromStored(note.content).trim();
  if (markdown.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('The lesson summary is empty.')),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: markdown));
  messenger.showSnackBar(
    const SnackBar(content: Text('Lesson summary copied.')),
  );
}

/// Asks for plain text, Markdown, or JSON and returns the Markdown to append.
Future<String?> showAddToLessonSummaryDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _AddToSummaryDialog(),
  );
}

class _AddToSummaryDialog extends StatefulWidget {
  const _AddToSummaryDialog();

  @override
  State<_AddToSummaryDialog> createState() => _AddToSummaryDialogState();
}

class _AddToSummaryDialogState extends State<_AddToSummaryDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _submit() {
    try {
      Navigator.of(context).pop(LessonSummaryInput.parse(_controller.text));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to lesson summary'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste plain text, Markdown, or JSON. It is added to the end of '
              'the summary.\nJSON: {"title": "...", "content": "..."}, '
              '{"summary": "..."}, or a list of those.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Paste here…',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _paste,
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
