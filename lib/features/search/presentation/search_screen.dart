import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/study_navigator.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../favorites/data/favorites_display_providers.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../data/search_providers.dart';
import '../domain/study_search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final categoriesAsync = ref.watch(studyPinCategoriesProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Study Vault'),
        actions: [
          IconButton(
            tooltip: 'Favorites',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
            icon: const Icon(Icons.star_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 48 : 16,
              8,
              isWide ? 48 : 16,
              8,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search classes, lessons, notes, flashcards…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: queryState.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).setQuery('');
                        },
                      ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).setQuery(value);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final filter in SearchResultFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: queryState.typeFilter == filter,
                      onSelected: (_) {
                        ref
                            .read(searchQueryProvider.notifier)
                            .setTypeFilter(filter);
                      },
                    ),
                  ),
                FilterChip(
                  label: const Text('Favorites only'),
                  selected: queryState.favoritesOnly,
                  onSelected: (v) {
                    ref.read(searchQueryProvider.notifier).setFavoritesOnly(v);
                  },
                ),
              ],
            ),
          ),
          if (queryState.typeFilter == SearchResultFilter.pins ||
              queryState.typeFilter == SearchResultFilter.all)
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (cats) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Any category'),
                        selected: queryState.categoryId == null,
                        onSelected: (_) {
                          ref
                              .read(searchQueryProvider.notifier)
                              .setCategoryId(null);
                        },
                      ),
                    ),
                    for (final cat in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: queryState.categoryId == cat.id,
                          avatar: CircleAvatar(
                            backgroundColor: Color(cat.colorValue),
                            radius: 6,
                          ),
                          onSelected: (_) {
                            ref
                                .read(searchQueryProvider.notifier)
                                .setCategoryId(
                                  queryState.categoryId == cat.id
                                      ? null
                                      : cat.id,
                                );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: queryState.query.trim().isEmpty
                ? _InitialSearchBody(theme: theme)
                : resultsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Search failed: $e')),
                    data: (results) {
                      if (results.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          title: 'No results',
                          message:
                              'No results for "${queryState.query.trim()}"',
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 48 : 16,
                          0,
                          isWide ? 48 : 16,
                          24,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final r = results[index];
                          return _SearchResultTile(result: r);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InitialSearchBody extends ConsumerWidget {
  const _InitialSearchBody({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(homeFavoritesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Search classes, subjects, lessons, materials and annotations.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        favs.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Favorites', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final item in items.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.star),
                    title: Text(item.title),
                    subtitle: Text(item.breadcrumb),
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
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.result});

  final StudySearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      leading: Icon(_iconFor(result.kind)),
      title: Row(
        children: [
          Expanded(child: AutoDirectionText(result.title)),
          if (result.isFavorite)
            Icon(Icons.star, size: 16, color: theme.colorScheme.tertiary),
        ],
      ),
      subtitle: AutoDirectionText(
        [
          if (result.subtitle != null) result.subtitle!,
          result.breadcrumb,
          if (result.matchedSnippet != null) '"${result.matchedSnippet}"',
        ].join('\n'),
      ),
      isThreeLine: true,
      onTap: () => StudyNavigator.openSearchResult(context, ref, result),
    );
  }

  IconData _iconFor(StudyEntityKind kind) => switch (kind) {
    StudyEntityKind.class_ => Icons.class_outlined,
    StudyEntityKind.subject => Icons.menu_book_outlined,
    StudyEntityKind.lesson => Icons.article_outlined,
    StudyEntityKind.material => Icons.attach_file,
    StudyEntityKind.studyPin => Icons.push_pin_outlined,
    StudyEntityKind.note => Icons.sticky_note_2_outlined,
    StudyEntityKind.flashcard => Icons.style_outlined,
    StudyEntityKind.bookmark => Icons.bookmark_outline,
  };
}
