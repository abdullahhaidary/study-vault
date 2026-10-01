import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/built_in_data.dart';
import '../../../core/navigation/study_navigator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../search/domain/study_search_result.dart';
import '../data/favorites_display_providers.dart';
import 'favorite_star_button.dart';

/// Dedicated Favorites screen.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(favoriteDisplayItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'All'),
                  (FavoriteEntityType.subject, 'Subjects'),
                  (FavoriteEntityType.lesson, 'Lessons'),
                  (FavoriteEntityType.material, 'Materials'),
                  (FavoriteEntityType.studyPin, 'Pins'),
                  (FavoriteEntityType.class_, 'Classes'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                final filtered = _filter == 'all'
                    ? items
                    : items.where((i) => i.entityType == _filter).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.star_border,
                    title: 'No favorites yet',
                    message:
                        'Star subjects, lessons, materials, or pins to see them here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      leading: Icon(_iconFor(item.entityType)),
                      title: Text(item.title),
                      subtitle: Text(
                        [
                          if (item.subtitle != null) item.subtitle!,
                          item.breadcrumb,
                        ].where((s) => s.isNotEmpty).join('\n'),
                      ),
                      isThreeLine: item.subtitle != null,
                      trailing: FavoriteStarButton(
                        entityType: item.entityType,
                        entityId: item.entityId,
                      ),
                      onTap: () => StudyNavigator.openEntity(
                        context,
                        ref,
                        kind: item.kind,
                        id: item.entityId,
                        materialId: item.materialId,
                        materialTitle: item.materialTitle,
                        mimeType: item.mimeType,
                        pageNumber: item.pageNumber,
                        focusPinId: item.kind == StudyEntityKind.studyPin
                            ? item.entityId
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
    FavoriteEntityType.class_ => Icons.class_outlined,
    FavoriteEntityType.subject => Icons.menu_book_outlined,
    FavoriteEntityType.lesson => Icons.article_outlined,
    FavoriteEntityType.material => Icons.attach_file,
    FavoriteEntityType.studyPin => Icons.push_pin_outlined,
    _ => Icons.star_border,
  };
}
