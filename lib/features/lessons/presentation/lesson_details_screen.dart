import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../data/lessons_providers.dart';
import '../data/materials_providers.dart';
import 'create_lesson_dialog.dart';

/// Lesson page — attach and open local PDF study materials.
class LessonDetailsScreen extends ConsumerWidget {
  const LessonDetailsScreen({super.key, required this.lessonId});

  final String lessonId;

  Future<void> _attachPdf(BuildContext context, WidgetRef ref) async {
    try {
      final material = await attachPdfToLesson(ref, lessonId: lessonId);
      if (material != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attached ${material.title}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach PDF: $error')),
        );
      }
    }
  }

  Future<void> _openMaterial(
    BuildContext context,
    LessonMaterial material,
  ) async {
    final path = await materialAbsolutePath(material);
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.pdfStudy,
      arguments: {
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
        title: const Text('Remove PDF?'),
        content: Text(
          '"${material.title}" will be removed from this lesson and deleted '
          'from local Study Vault storage.',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonByIdProvider(lessonId));
    final materialsAsync = ref.watch(materialsForLessonProvider(lessonId));
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return lessonAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
                  IconButton(
                    tooltip: 'Edit lesson',
                    onPressed: () => CreateLessonDialog.show(
                      context,
                      subjectId: lesson.subjectId,
                      existing: lesson,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton.icon(
                        onPressed: () => _attachPdf(context, ref),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Attach PDF'),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Attach PDF',
                      onPressed: () => _attachPdf(context, ref),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                ],
              ),
              if (lesson.description != null &&
                  lesson.description!.isNotEmpty)
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
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'No PDFs yet',
                        message:
                            'Attach a local PDF to open and study it here.',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final material = materials[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GroupedItemTile(
                              title: material.title,
                              subtitle: 'Tap to open and study',
                              icon: Icons.picture_as_pdf_outlined,
                              onTap: () => _openMaterial(context, material),
                              onDelete: () =>
                                  _confirmDelete(context, ref, material),
                            ),
                          );
                        },
                        childCount: materials.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: isWide
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _attachPdf(context, ref),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Attach PDF'),
                ),
        );
      },
    );
  }
}
