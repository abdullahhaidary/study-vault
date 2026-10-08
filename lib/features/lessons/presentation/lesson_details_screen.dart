import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../../core/widgets/section_header.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../ai_questions/presentation/question_sets_screen.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../../flashcards/presentation/flashcards_list_screen.dart';
import '../../notes/presentation/notes_list_section.dart';
import '../../pdf_ai_materials/presentation/pdf_ai_materials_sheet.dart';
import '../data/bookmarks_providers.dart';
import '../data/lesson_progress_providers.dart';
import '../domain/lesson_progress.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_entry_button.dart';
import '../data/lessons_providers.dart';
import '../data/materials_providers.dart';
import 'create_lesson_dialog.dart';
import 'lesson_images_screen.dart';

/// Lesson page — attach and open local PDF / image study materials.
class LessonDetailsScreen extends ConsumerWidget {
  const LessonDetailsScreen({super.key, required this.lessonId});

  final String lessonId;

  Future<void> _attachPdf(BuildContext context, WidgetRef ref) async {
    try {
      final material = await attachPdfToLesson(ref, lessonId: lessonId);
      if (material != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attached ${material.title}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not attach PDF: $error')));
      }
    }
  }

  Future<void> _openMaterial(
    BuildContext context,
    LessonMaterial material,
  ) async {
    final path = await materialAbsolutePath(material);
    if (!context.mounted) return;

    if (isImageMimeType(material.mimeType)) {
      await Navigator.of(context).pushNamed(
        AppRoutes.imageStudy,
        arguments: {
          'resourceId': material.id,
          'title': material.title,
          'filePath': path,
        },
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.pdfStudy,
      arguments: {
        'resourceId': material.id,
        'title': material.title,
        'filePath': path,
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonMaterial material,
  ) async {
    final isImage = isImageMimeType(material.mimeType);
    final confirmed = await confirmDelete(
      context,
      title: isImage ? 'Remove image?' : 'Remove PDF?',
      message:
          '"${material.title}" will be removed from this lesson and deleted '
          'from local Study Vault storage. Study Pins, AI materials, and '
          'quizzes for this attachment will also be removed.',
      confirmLabel: 'Remove',
    );
    if (confirmed) await deleteLessonMaterial(ref, material: material);
  }

  Future<void> _confirmDeleteLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete lesson?',
      message:
          '"${lesson.name}" and all of its PDFs, images, notes, pins, '
          'flashcards, and quizzes will be permanently deleted.',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    await deleteLesson(ref, lessonId: lesson.id);
  }

  Future<void> _openAiStudyMaterials(
    BuildContext context,
    WidgetRef ref,
    List<LessonMaterial> materials,
  ) async {
    final pdfs = [
      for (final material in materials)
        if (isPdfMimeType(material.mimeType)) material,
    ];
    if (pdfs.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attach a PDF to this chapter to use AI Study Materials.',
          ),
        ),
      );
      return;
    }

    LessonMaterial? selected = pdfs.length == 1 ? pdfs.first : null;
    selected ??= await showModalBottomSheet<LessonMaterial>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Choose a PDF',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final pdf in pdfs)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(pdf.title),
                onTap: () => Navigator.pop(context, pdf),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final path = await materialAbsolutePath(selected);
    if (!context.mounted) return;
    await showPdfAiMaterialsSheet(
      context,
      materialId: selected.id,
      title: selected.title,
      filePath: path,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));
    final materialsAsync = ref.watch(materialsForLessonProvider(lessonId));
    final flashcardCount = ref
        .watch(flashcardCountForLessonProvider(lessonId))
        .valueOrNull;
    final bookmarkCount = ref
        .watch(bookmarkCountForLessonProvider(lessonId))
        .valueOrNull;
    final materials = materialsAsync.valueOrNull ?? const [];
    final imageCount = materials
        .where((m) => isImageMimeType(m.mimeType))
        .length;
    final imageSubtitle = materialsAsync.isLoading
        ? 'Open images'
        : imageCount == 0
        ? 'No images yet'
        : imageCount == 1
        ? '1 image'
        : '$imageCount images';

    return lessonAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: const AppErrorState(message: 'Could not load this lesson.'),
      ),
      data: (lesson) {
        if (lesson == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorState(message: 'Lesson not found'),
          );
        }

        final desktop = AppSpacing.isDesktopLayout(context);
        final materialsBody = _materialsBody(context, ref, materialsAsync);
        final studyTools = _studyTools(
          context,
          ref,
          lesson: lesson,
          materialsAsync: materialsAsync,
          flashcardCount: flashcardCount,
          bookmarkCount: bookmarkCount,
          imageSubtitle: imageSubtitle,
        );

        return DetailScaffold(
          title: lesson.name,
          description: lesson.description,
          actions: [
            _LessonProgressBadge(
              status: LessonProgressStatus.fromStorage(lesson.progressStatus),
              onSelected: (status) =>
                  setLessonProgress(ref, lesson: lesson, status: status),
            ),
            FavoriteStarButton(
              entityType: FavoriteEntityType.lesson,
              entityId: lessonId,
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'edit') {
                  CreateLessonDialog.show(
                    context,
                    subjectId: lesson.subjectId,
                    existing: lesson,
                  );
                } else if (value == 'import') {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.manualEntry, arguments: lessonId);
                } else if (value == 'delete') {
                  _confirmDeleteLesson(context, ref, lesson);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit lesson')),
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import from JSON'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete lesson',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _attachPdf(context, ref),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Attach PDF'),
          ),
          bodySlivers: [
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.sm,
                child: ReviewEntryButton(
                  scope: ReviewScope(
                    type: ReviewScopeType.lesson,
                    id: lessonId,
                    title: lesson.name,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.md,
                child: AiDiscussionsSection(
                  kind: AiContextKind.lesson,
                  id: lessonId,
                ),
              ),
            ),
            if (desktop)
              SliverToBoxAdapter(
                child: DetailContent(
                  bottom: AppSpacing.md,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'Materials'),
                            materialsBody,
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'Study tools'),
                            studyTools,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _ContiguousSliver(
                children: [
                  DetailContent(
                    bottom: AppSpacing.xs,
                    child: const SectionHeader(title: 'Materials'),
                  ),
                  DetailContent(bottom: AppSpacing.md, child: materialsBody),
                ],
              ),
              _ContiguousSliver(
                children: [
                  DetailContent(
                    bottom: AppSpacing.xs,
                    child: const SectionHeader(title: 'Study tools'),
                  ),
                  DetailContent(bottom: AppSpacing.md, child: studyTools),
                ],
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        );
      },
    );
  }

  Widget _studyTools(
    BuildContext context,
    WidgetRef ref, {
    required Lesson lesson,
    required AsyncValue<List<LessonMaterial>> materialsAsync,
    required int? flashcardCount,
    required int? bookmarkCount,
    required String imageSubtitle,
  }) {
    return Column(
      children: [
        _StudyToolTile(
          icon: Icons.style_outlined,
          title: 'Flashcards',
          subtitle: flashcardCount == null
              ? 'Open flashcards'
              : flashcardCount == 1
              ? '1 card'
              : '$flashcardCount cards',
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.flashcardsList,
            arguments: FlashcardsListScope.lesson(
              id: lessonId,
              title: lesson.name,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StudyToolTile(
          icon: Icons.image_outlined,
          title: 'Images',
          subtitle: imageSubtitle,
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.lessonImages,
            arguments: LessonImagesScope(
              lessonId: lessonId,
              title: lesson.name,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StudyToolTile(
          icon: Icons.quiz_outlined,
          title: 'AI Questions',
          subtitle: 'Generated quizzes',
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.questionSets,
            arguments: QuestionSetsScope.lesson(
              id: lessonId,
              title: lesson.name,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StudyToolTile(
          icon: Icons.library_books_outlined,
          title: 'AI Study Materials',
          subtitle: 'Summary · Explanation · Deep Explanation',
          onTap: () => _openAiStudyMaterials(
            context,
            ref,
            materialsAsync.valueOrNull ?? const [],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        NotesListSection.lesson(lessonId: lessonId),
        const SizedBox(height: AppSpacing.xs),
        _StudyToolTile(
          icon: Icons.bookmark_outline,
          title: 'Bookmarks',
          subtitle: bookmarkCount == null
              ? 'Saved pages'
              : bookmarkCount == 1
              ? '1 bookmark'
              : '$bookmarkCount bookmarks',
          interactive: false,
        ),
      ],
    );
  }

  Widget _materialsBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<LessonMaterial>> materialsAsync,
  ) {
    final theme = Theme.of(context);
    return materialsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoading(),
      ),
      error: (error, _) =>
          const AppErrorState(message: 'Could not load materials.'),
      data: (materials) {
        final pdfs = [
          for (final material in materials)
            if (isPdfMimeType(material.mimeType)) material,
        ];
        if (pdfs.isEmpty) {
          return Text(
            'No PDFs yet. Attach a PDF to study here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final material in pdfs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: GroupedItemTile(
                  title: material.title,
                  subtitle: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  onTap: () => _openMaterial(context, material),
                  onDelete: () => _confirmDelete(context, ref, material),
                  deleteLabel: 'Remove',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LessonProgressBadge extends StatelessWidget {
  const _LessonProgressBadge({required this.status, required this.onSelected});

  final LessonProgressStatus status;
  final ValueChanged<LessonProgressStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(status, theme.colorScheme);

    return PopupMenuButton<LessonProgressStatus>(
      tooltip: 'Change progress',
      initialValue: status,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in LessonProgressStatus.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == status ? Icons.check_circle : Icons.circle_outlined,
                  size: 19,
                  color: _colorFor(option, theme.colorScheme),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(option.label),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'Progress: ${status.label}',
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(status), size: 16, color: color),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                status.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(LessonProgressStatus value) => switch (value) {
    LessonProgressStatus.notStarted => Icons.circle_outlined,
    LessonProgressStatus.studying => Icons.menu_book_outlined,
    LessonProgressStatus.reviewed => Icons.task_alt,
    LessonProgressStatus.mastered => Icons.workspace_premium_outlined,
  };

  Color _colorFor(LessonProgressStatus value, ColorScheme colors) =>
      switch (value) {
        LessonProgressStatus.notStarted => colors.onSurfaceVariant,
        LessonProgressStatus.studying => colors.primary,
        LessonProgressStatus.reviewed => colors.tertiary,
        LessonProgressStatus.mastered => const Color(0xFF2E7D32),
      };
}

/// Wraps non-sliver children into a single [SliverToBoxAdapter] column.
class _ContiguousSliver extends StatelessWidget {
  const _ContiguousSliver({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _StudyToolTile extends StatelessWidget {
  const _StudyToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.interactive = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = interactive && onTap != null;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouch.min),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
