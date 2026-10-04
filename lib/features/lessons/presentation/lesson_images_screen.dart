import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../data/materials_providers.dart';

/// Arguments for the lesson images list screen.
class LessonImagesScope {
  const LessonImagesScope({required this.lessonId, required this.title});

  final String lessonId;
  final String title;
}

/// Flashcard-style list of lesson images — empty until opened and populated.
class LessonImagesScreen extends ConsumerWidget {
  const LessonImagesScreen({super.key, required this.scope});

  final LessonImagesScope scope;

  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    try {
      final material = await attachImageToLesson(ref, lessonId: scope.lessonId);
      if (material != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added ${material.title}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add image: $error')));
      }
    }
  }

  Future<void> _openImage(BuildContext context, LessonMaterial material) async {
    final path = await materialAbsolutePath(material);
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.imageStudy,
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
        title: const Text('Remove image?'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(
      materialsForLessonProvider(scope.lessonId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(scope.title),
        actions: [
          IconButton(
            tooltip: 'Add image from gallery',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _addImage(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addImage(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add image'),
      ),
      body: ScrollEdgeArrows(
        // Keep the down arrow clear of the extended FAB.
        bottomPadding: 72,
        child: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load images: $error')),
          data: (materials) {
            final images = [
              for (final material in materials)
                if (isImageMimeType(material.mimeType)) material,
            ];
            if (images.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No images yet.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add a review image from your gallery.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final material = images[index];
                return _ImageListTile(
                  material: material,
                  onOpen: () => _openImage(context, material),
                  onDelete: () => _confirmDelete(context, ref, material),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ImageListTile extends StatefulWidget {
  const _ImageListTile({
    required this.material,
    required this.onOpen,
    required this.onDelete,
  });

  final LessonMaterial material;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_ImageListTile> createState() => _ImageListTileState();
}

class _ImageListTileState extends State<_ImageListTile> {
  late final Future<String> _pathFuture;

  @override
  void initState() {
    super.initState();
    _pathFuture = materialAbsolutePath(widget.material);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.colorScheme.surfaceContainerLow,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: FutureBuilder<String>(
            future: _pathFuture,
            builder: (context, snapshot) {
              final path = snapshot.data;
              if (path == null) {
                return ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                cacheHeight: (48 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.outline,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      title: Text(widget.material.title),
      subtitle: const Text('Image'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Image options',
        onSelected: (value) {
          if (value == 'remove') widget.onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'remove',
            child: Text(
              'Remove',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
      onTap: widget.onOpen,
    );
  }
}
