import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/built_in_data.dart';
import '../../../core/navigation/study_navigator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../search/domain/study_search_result.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_setup_screen.dart';
import '../data/favorites_display_providers.dart';
import 'favorite_star_button.dart';

/// Dedicated Favorites screen.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(favoriteDisplayItemsProvider);
    final theme = Theme.of(context);
    final page = AppSpacing.pageInsets(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: const Text('Favorites'),
        actions: [
          TextButton.icon(
            onPressed: () => openReviewSetup(
              context,
              scope: const ReviewScope(
                type: ReviewScopeType.favorites,
                title: 'Favorite Pins',
              ),
              filters: const ReviewSessionFilters(favoritesOnly: true),
            ),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Review'),
          ),
        ],
      ),
      body: ScrollEdgeArrows(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: page.left,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  for (final entry in const [
                    ('all', 'All'),
                    (FavoriteEntityType.subject, 'Subjects'),
                    (FavoriteEntityType.lesson, 'Lessons'),
                    (FavoriteEntityType.material, 'Materials'),
                    (FavoriteEntityType.studyPin, 'Pins'),
                    (FavoriteEntityType.note, 'Notes'),
                    (FavoriteEntityType.flashcard, 'Flashcards'),
                    (FavoriteEntityType.class_, 'Classes'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
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
                loading: () => const AppLoading(),
                error: (e, _) =>
                    const AppErrorState(message: 'Could not load favorites.'),
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
                    padding: EdgeInsets.fromLTRB(
                      page.left,
                      AppSpacing.xs,
                      page.right,
                      AppSpacing.xl,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSpacing.contentMaxWidth,
                          ),
                          child: ListTile(
                            tileColor: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.mdAll,
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            leading: Icon(
                              _iconFor(item.entityType),
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              [
                                if (item.subtitle != null) item.subtitle!,
                                item.breadcrumb,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
    FavoriteEntityType.class_ => Icons.class_outlined,
    FavoriteEntityType.subject => Icons.menu_book_outlined,
    FavoriteEntityType.lesson => Icons.article_outlined,
    FavoriteEntityType.material => Icons.attach_file,
    FavoriteEntityType.studyPin => Icons.push_pin_outlined,
    FavoriteEntityType.note => Icons.sticky_note_2_outlined,
    FavoriteEntityType.flashcard => Icons.style_outlined,
    _ => Icons.star_border,
  };
}
