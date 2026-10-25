import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_assistant/services/quill_to_markdown.dart';
import '../../reference_books/presentation/lecture_book_links.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../data/course_review_providers.dart';
import '../domain/course_review_models.dart';
import '../domain/course_review_prompts.dart';

/// One complete, editable Course Review for a subject.
class CourseReviewScreen extends ConsumerWidget {
  const CourseReviewScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(courseReviewProvider(subjectId));
    return async.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const AppErrorState(message: 'Could not load the Course Review.'),
      ),
      data: (state) {
        if (state == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorState(message: 'Subject not found'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Course Review'),
                Text(
                  state.subject.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          body: _ReviewBody(subjectId: subjectId, state: state),
        );
      },
    );
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.subjectId, required this.state});

  final String subjectId;
  final CourseReviewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final document = state.document;
    return ListView(
      padding: AppSpacing.pageInsets(
        context,
      ).copyWith(top: AppSpacing.md, bottom: 96),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppSpacing.contentWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPrompt(context, state),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy prompt for complete review'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (document == null)
                  _MissingDocument(state: state, onEdit: _openEditor)
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Version ${document.version}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openEditor(context, ref, state),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit complete review'),
                      ),
                    ],
                  ),
                  if (state.documentOutdated) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Outdated. Included lectures or their study materials '
                      'changed after this review was saved. The document was '
                      'not changed automatically.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SelectionArea(
                    child: StudyMarkdown(
                      data: document.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Lectures', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Include the PDFs that belong in this review. Excluding one '
                  'marks a saved review outdated and does not rewrite it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.sources.isEmpty)
                  Text(
                    'No documents in this subject yet. Attach lecture PDFs or '
                    'text documents to lessons, then include them here.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final source in state.sources)
                    _SourceTile(source: source),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyPrompt(
    BuildContext context,
    CourseReviewState state,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: CourseReviewPrompts.completeReviewPrompt(state)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const TransientSnackBar(
        content: Text(
          'Prompt copied. Paste it into an external AI with the lesson materials.',
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CourseReviewState state, {
    String? initialMarkdown,
    String? title,
  }) async {
    final source = initialMarkdown ?? state.document?.content ?? '';
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FullExplanationScreen(
          initialText: source.trim().isEmpty
              ? ''
              : MarkdownToQuill.toDeltaJson(source),
          title:
              title ??
              (state.document == null
                  ? 'Create complete review'
                  : 'Edit complete review'),
        ),
      ),
    );
    if (edited == null || !context.mounted) return;
    final markdown = QuillToMarkdown.fromStored(edited).trim();
    if (markdown.isEmpty) {
      _message(context, 'A complete review cannot be empty.');
      return;
    }
    final current = state.document?.content.trim();
    if (initialMarkdown == null && current != null && markdown == current) {
      return;
    }
    final saved = await ref
        .read(courseReviewServiceProvider)
        .saveCompleteDocument(subjectId: subjectId, content: markdown);
    if (!context.mounted) return;
    _message(context, 'Saved as v${saved.version}.');
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(TransientSnackBar(content: Text(text)));
  }
}

class _MissingDocument extends ConsumerWidget {
  const _MissingDocument({required this.state, required this.onEdit});

  final CourseReviewState state;
  final Future<void> Function(
    BuildContext context,
    WidgetRef ref,
    CourseReviewState state, {
    String? initialMarkdown,
    String? title,
  })
  onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('No complete review yet', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Paste one Markdown document for the whole subject.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => onEdit(context, ref, state),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Create / paste complete review'),
          ),
        ),
        if (state.hasLegacyContent) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Older Summary, Explanation, and Examples entries are still saved. '
            'Combine the included ones into a document you can edit. Saving '
            'does not delete the old entries.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _combine(context, ref),
              icon: const Icon(Icons.merge_type),
              label: const Text('Combine existing review'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _combine(BuildContext context, WidgetRef ref) async {
    final markdown = ref
        .read(courseReviewServiceProvider)
        .compileLegacyDocument(state);
    if (!markdown.contains('## ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const TransientSnackBar(
          content: Text(
            'Include a lecture that already has review sections, then combine.',
          ),
        ),
      );
      return;
    }
    await onEdit(
      context,
      ref,
      state,
      initialMarkdown: markdown,
      title: 'Combine existing review',
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});

  final CourseReviewSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final excluded = source.excluded;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              excluded ? Icons.block : Icons.description_outlined,
              color: excluded
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            title: Text(
              source.material.title,
              style: excluded
                  ? TextStyle(color: theme.colorScheme.outline)
                  : null,
            ),
            subtitle: Text(
              excluded
                  ? '${source.lesson.name} · Excluded'
                  : source.lesson.name,
            ),
            trailing: TextButton(
              onPressed: () => ref
                  .read(courseReviewServiceProvider)
                  .setExcluded(source, !excluded),
              child: Text(excluded ? 'Include' : 'Exclude'),
            ),
          ),
          LectureBookLinks(materialId: source.material.id),
        ],
      ),
    );
  }
}
