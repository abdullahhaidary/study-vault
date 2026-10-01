import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../favorites/presentation/favorite_star_button.dart';
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
