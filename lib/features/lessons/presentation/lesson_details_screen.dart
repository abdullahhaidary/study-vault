import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../../core/widgets/section_header.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../../flashcards/presentation/flashcards_list_screen.dart';
import '../../notes/presentation/notes_list_section.dart';
import '../data/bookmarks_providers.dart';
import '../data/lesson_progress_providers.dart';
import '../domain/lesson_progress.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_entry_button.dart';
import '../data/lessons_providers.dart';
import '../data/materials_providers.dart';
import 'create_lesson_dialog.dart';

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

  Future<void> _attachImage(BuildContext context, WidgetRef ref) async {
    try {
      final material = await attachImageToLesson(ref, lessonId: lessonId);
      if (material != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attached ${material.title}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $error')),
        );
      }
    }
  }

  Future<void> _showAttachMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Attach PDF'),
              onTap: () {
                Navigator.pop(context);
                _attachPdf(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Attach image'),
              onTap: () {
                Navigator.pop(context);
                _attachImage(context, ref);
              },
            ),
          ],
        ),
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isImageMimeType(material.mimeType) ? 'Remove image?' : 'Remove PDF?',
        ),
        content: Text(
          '"${material.title}" will be removed from this lesson and deleted '
          'from local Study Vault storage. Study Pins on this resource will '
          'also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteLessonMaterial(ref, material: material);
    }
  }

  IconData _iconFor(LessonMaterial material) {
    return isImageMimeType(material.mimeType)
        ? Icons.image_outlined
        : Icons.picture_as_pdf_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));
    final materialsAsync = ref.watch(materialsForLessonProvider(lessonId));
    final theme = Theme.of(context);
    final flashcardCount = ref
        .watch(flashcardCountForLessonProvider(lessonId))
        .valueOrNull;
    final bookmarkCount = ref
        .watch(bookmarkCountForLessonProvider(lessonId))
        .valueOrNull;

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

        return DetailScaffold(
          title: lesson.name,
          description: lesson.description,
          actions: [
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
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit lesson')),
              ],
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAttachMenu(context, ref),
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Material'),
          ),
          bodySlivers: [
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.md,
                child: DropdownButtonFormField<LessonProgressStatus>(
                  initialValue: LessonProgressStatus.fromStorage(
                    lesson.progressStatus,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Progress',
                    prefixIcon: Icon(Icons.track_changes_outlined),
                  ),
                  items: [
                    for (final status in LessonProgressStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (status) {
                    if (status != null) {
                      setLessonProgress(ref, lesson: lesson, status: status);
                    }
                  },
                ),
              ),
            ),
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
            materialsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppLoading(),
                ),
              ),
              error: (error, _) => const SliverToBoxAdapter(
                child: DetailContent(
                  child: AppErrorState(message: 'Could not load materials.'),
                ),
              ),
              data: (materials) {
                return _ContiguousSliver(
                  children: [
                    DetailContent(
                      bottom: AppSpacing.xs,
                      child: const SectionHeader(title: 'Materials'),
                    ),
                    if (materials.isEmpty)
                      DetailContent(
                        bottom: AppSpacing.md,
                        child: Text(
                          'No materials yet. Attach a PDF or image to study here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      DetailContent(
                        bottom: AppSpacing.md,
                        child: Column(
                          children: [
                            for (final material in materials)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: GroupedItemTile(
                                  title: material.title,
                                  subtitle: isImageMimeType(material.mimeType)
                                      ? 'Image'
                                      : 'PDF',
                                  icon: _iconFor(material),
                                  onTap: () => _openMaterial(context, material),
                                  onDelete: () =>
                                      _confirmDelete(context, ref, material),
                                  deleteLabel: 'Remove',
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            _ContiguousSliver(
              children: [
                DetailContent(
                  bottom: AppSpacing.xs,
                  child: const SectionHeader(title: 'Study tools'),
                ),
                DetailContent(
                  bottom: AppSpacing.md,
                  child: Column(
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
                  ),
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        );
      },
    );
  }
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
