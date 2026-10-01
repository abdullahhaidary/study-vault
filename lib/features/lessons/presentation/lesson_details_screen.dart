import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
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
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return lessonAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (lesson) {
        if (lesson == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Lesson not found')),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(lesson.name),
                actions: [
                  FavoriteStarButton(
                    entityType: FavoriteEntityType.lesson,
                    entityId: lessonId,
                  ),
                  IconButton(
                    tooltip: 'Edit lesson',
                    onPressed: () => CreateLessonDialog.show(
                      context,
                      subjectId: lesson.subjectId,
                      existing: lesson,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (isWide) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _attachImage(context, ref),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Attach image'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton.icon(
                        onPressed: () => _attachPdf(context, ref),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Attach PDF'),
                      ),
                    ),
                  ] else
                    IconButton(
                      tooltip: 'Attach material',
                      onPressed: () => _showAttachMenu(context, ref),
                      icon: const Icon(Icons.attach_file),
                    ),
                ],
              ),
              if (lesson.description != null && lesson.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      lesson.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    children: [
                      _CountTile(
                        icon: Icons.style_outlined,
                        label: 'Flashcards',
                        count: ref
                            .watch(flashcardCountForLessonProvider(lessonId))
                            .valueOrNull,
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.flashcardsList,
                          arguments: FlashcardsListScope.lesson(
                            id: lessonId,
                            title: lesson.name,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CountTile(
                        icon: Icons.bookmark_outline,
                        label: 'Bookmarks',
                        count: ref
                            .watch(bookmarkCountForLessonProvider(lessonId))
                            .valueOrNull,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: NotesListSection.lesson(lessonId: lessonId),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    'Study materials',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              materialsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $error')),
                ),
                data: (materials) {
                  if (materials.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'No materials yet',
                        message:
                            'Attach a local PDF or image to study it here.',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final material = materials[index];
                        final kind = isImageMimeType(material.mimeType)
                            ? 'Image'
                            : 'PDF';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GroupedItemTile(
                            title: material.title,
                            subtitle: '$kind · Tap to open and study',
                            icon: _iconFor(material),
                            onTap: () => _openMaterial(context, material),
                            onDelete: () =>
                                _confirmDelete(context, ref, material),
                          ),
                        );
                      }, childCount: materials.length),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: isWide
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showAttachMenu(context, ref),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                ),
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    this.count,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
              Text('${count ?? 0}'),
            ],
          ),
        ),
      ),
    ),
  );
}
