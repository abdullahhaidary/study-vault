import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../../core/widgets/transient_snack_bar.dart';
import '../data/materials_providers.dart';

/// Arguments for the lesson images list screen.
class LessonImagesScope {
  const LessonImagesScope({required this.lessonId, required this.title});

  final String lessonId;
  final String title;
}

/// Lesson images with a device-local choice of thumbnail grid or compact list.
class LessonImagesScreen extends ConsumerStatefulWidget {
  const LessonImagesScreen({super.key, required this.scope});

  final LessonImagesScope scope;

  @override
  ConsumerState<LessonImagesScreen> createState() => _LessonImagesScreenState();
}

class _LessonImagesScreenState extends ConsumerState<LessonImagesScreen> {
  static const _layoutKey = 'lesson_images_grid_view_v1';
  bool _gridView = true;
  bool _layoutChanged = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && !_layoutChanged) {
        setState(() => _gridView = prefs.getBool(_layoutKey) ?? true);
      }
    } catch (_) {
      // Browsing images still works when device preferences are unavailable.
    }
  }

  Future<void> _toggleLayout() async {
    final grid = !_gridView;
    setState(() {
      _gridView = grid;
      _layoutChanged = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_layoutKey, grid);
    } catch (_) {
      // Keep the selected layout usable for this visit.
    }
  }

  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    try {
      final material = await attachImageToLesson(
        ref,
        lessonId: widget.scope.lessonId,
      );
      if (material != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          TransientSnackBar(content: Text('Added ${material.title}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          TransientSnackBar(content: Text('Could not add image: $error')),
        );
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
    final confirmed = await confirmDelete(
      context,
      title: 'Remove image?',
      message:
          '"${material.title}" will be removed from this lesson and deleted '
          'from local StudyDesk storage. Study Pins on this resource will '
          'also be removed.',
      confirmLabel: 'Remove',
    );
    if (confirmed && mounted) {
      await deleteLessonMaterial(ref, material: material);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(
      materialsForLessonProvider(widget.scope.lessonId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scope.title),
        actions: [
          IconButton(
            tooltip: _gridView ? 'Switch to list view' : 'Switch to grid view',
            icon: Icon(
              _gridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
            ),
            onPressed: _toggleLayout,
          ),
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

            Widget itemBuilder(BuildContext context, int index) {
              final material = images[index];
              return _ImageItem(
                key: ValueKey(material.id),
                material: material,
                gridView: _gridView,
                onOpen: () => _openImage(context, material),
                onDelete: () => _confirmDelete(context, ref, material),
              );
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppSpacing.contentWidth(context),
                ),
                child: _gridView
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final available = constraints.maxWidth - 32;
                          final columns = (available / 180).floor().clamp(
                            available < 280 ? 1 : 2,
                            6,
                          );
                          final width =
                              (available - 12 * (columns - 1)) / columns;
                          final footerHeight =
                              (MediaQuery.textScalerOf(context).scale(20) * 2 +
                                      16)
                                  .clamp(64.0, double.infinity);
                          return GridView.builder(
                            key: PageStorageKey(
                              'lesson-images-grid:${widget.scope.lessonId}',
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: width * 0.85 + footerHeight,
                                ),
                            itemCount: images.length,
                            itemBuilder: itemBuilder,
                          );
                        },
                      )
                    : ListView.separated(
                        key: PageStorageKey(
                          'lesson-images-list:${widget.scope.lessonId}',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: itemBuilder,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageItem extends StatefulWidget {
  const _ImageItem({
    super.key,
    required this.material,
    required this.gridView,
    required this.onOpen,
    required this.onDelete,
  });

  final LessonMaterial material;
  final bool gridView;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_ImageItem> createState() => _ImageItemState();
}

class _ImageItemState extends State<_ImageItem> {
  late Future<String> _pathFuture;

  @override
  void initState() {
    super.initState();
    _pathFuture = materialAbsolutePath(widget.material);
  }

  @override
  void didUpdateWidget(covariant _ImageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.material.id != widget.material.id ||
        oldWidget.material.lessonId != widget.material.lessonId ||
        oldWidget.material.storedFileName != widget.material.storedFileName) {
      _pathFuture = materialAbsolutePath(widget.material);
    }
  }

  Widget _thumbnail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget broken() => ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: colors.outline),
      ),
    );
    return FutureBuilder<String>(
      future: _pathFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) return broken();
        final path = snapshot.data;
        if (path == null) {
          return ColoredBox(
            color: colors.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final pixels =
                (constraints.biggest.longestSide *
                        MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 1024);
            return ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Image(
                image: ResizeImage(
                  FileImage(File(path)),
                  width: pixels,
                  height: pixels,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: widget.gridView ? BoxFit.contain : BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => broken(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _options(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Image options',
    onSelected: (value) {
      if (value == 'remove') widget.onDelete();
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'remove',
        child: Text(
          'Remove',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.gridView) {
      return Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _thumbnail(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.material.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    _options(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.colorScheme.surfaceContainerLow,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 48, child: _thumbnail(context)),
      ),
      title: Text(widget.material.title),
      subtitle: const Text('Image'),
      trailing: _options(context),
      onTap: widget.onOpen,
    );
  }
}
