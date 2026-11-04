import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/navigation/study_navigator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../favorites/data/favorites_display_providers.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../data/search_providers.dart';
import '../domain/study_search_result.dart';
import '../domain/study_search_scope.dart';
import 'search_scope_picker.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.embeddedInShell = false,
    this.scope = const StudySearchScope.library(),
    this.initialFilter = SearchResultFilter.all,
  });
  final StudySearchScope scope;
  final SearchResultFilter initialFilter;
  static Future<void> open(
    BuildContext context, {
    StudySearchScope scope = const StudySearchScope.library(),
    SearchResultFilter filter = SearchResultFilter.all,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SearchScreen(scope: scope, initialFilter: filter),
    ),
  );

  /// When true, this screen is a shell tab (no back affordance / favorites action).
  final bool embeddedInShell;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final SearchSession _session;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _session = SearchSession(scope: widget.scope, filter: widget.initialFilter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final categories = await ref.read(studyPinCategoriesProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _SearchFiltersSheet(categories: categories, session: _session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(searchQueryProvider(_session));
    final resultsAsync = ref.watch(searchResultsProvider(_session));
    final needsFileIndex =
        queryState.typeFilter == SearchResultFilter.all ||
        queryState.typeFilter == SearchResultFilter.materials;
    final indexing = needsFileIndex
        ? ref.watch(fileSearchIndexProgressProvider).valueOrNull
        : null;
    final indexRequest = needsFileIndex
        ? ref.watch(fileSearchIndexRequestProvider(queryState.scope))
        : const AsyncData<void>(null);
    final theme = Theme.of(context);
    final page = AppSpacing.pageInsets(context);
    final activeChips = _activeFilterChips(queryState, ref);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(
          queryState.scope.kind == StudySearchScopeKind.library
              ? 'Search'
              : 'Search ${queryState.scope.title}',
        ),
      ),
      body: ScrollEdgeArrows(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                page.left,
                AppSpacing.xs,
                page.right,
                0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppSpacing.contentWidth(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText:
                              'Search lessons, files, or a topic inside them…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: queryState.query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _controller.clear();
                                    ref
                                        .read(
                                          searchQueryProvider(
                                            _session,
                                          ).notifier,
                                        )
                                        .setQuery('');
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          ref
                              .read(searchQueryProvider(_session).notifier)
                              .setQuery(value);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filledTonal(
                      tooltip: 'Filters',
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: activeChips.isNotEmpty,
                        smallSize: 8,
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                page.left,
                AppSpacing.sm,
                page.right,
                0,
              ),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppSpacing.contentWidth(context),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.folder_open, size: 18),
                          tooltip: queryState.scope.title,
                          label: Text(
                            queryState.scope.kind ==
                                    StudySearchScopeKind.library
                                ? 'Entire library'
                                : queryState.scope.title,
                          ),
                          onPressed: () async {
                            final scope = await showSearchScopePicker(
                              context,
                              ref.read(databaseProvider),
                            );
                            if (scope != null && mounted) {
                              ref
                                  .read(searchQueryProvider(_session).notifier)
                                  .setScope(scope);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        for (final filter in [
                          SearchResultFilter.all,
                          SearchResultFilter.lessons,
                          SearchResultFilter.materials,
                          SearchResultFilter.aiMaterials,
                          SearchResultFilter.notes,
                          SearchResultFilter.pins,
                          SearchResultFilter.flashcards,
                          SearchResultFilter.courseReview,
                          SearchResultFilter.books,
                        ]) ...[
                          ChoiceChip(
                            label: Text(filter.label),
                            selected: queryState.typeFilter == filter,
                            onSelected: (_) => ref
                                .read(searchQueryProvider(_session).notifier)
                                .setTypeFilter(filter),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (indexing?.running == true ||
                indexRequest.hasError ||
                (indexing?.unavailable ?? 0) > 0 ||
                (indexing?.withoutText ?? 0) > 0)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: page.left,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    if (indexing?.running == true)
                      const LinearProgressIndicator(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            indexRequest.hasError
                                ? 'Could not index file contents. Titles and saved study text are still searchable.'
                                : indexing?.running == true
                                ? 'Indexing files: ${indexing!.completed}/${indexing.total}. Matches appear as pages are indexed.'
                                : '${indexing?.unavailable ?? 0} files unavailable · ${indexing?.withoutText ?? 0} files have no searchable text (scans need OCR).',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (indexing?.running != true)
                          TextButton(
                            onPressed: () => ref.invalidate(
                              fileSearchIndexRequestProvider(queryState.scope),
                            ),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (activeChips.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  page.left,
                  AppSpacing.sm,
                  page.right,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppSpacing.contentWidth(context),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: activeChips,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: queryState.query.trim().isEmpty
                  ? _InitialSearchBody(theme: theme, scope: queryState.scope)
                  : resultsAsync.when(
                      loading: () => const AppLoading(),
                      error: (e, _) =>
                          const AppErrorState(message: 'Search failed.'),
                      data: (results) {
                        if (results.isEmpty) {
                          return EmptyState(
                            icon: Icons.search_off,
                            title: 'No results',
                            message:
                                'No matches for "${queryState.query.trim()}" in ${queryState.scope.title}. '
                                '${indexing?.running == true ? 'File indexing is still running.' : 'Try a shorter phrase or a wider scope.'}',
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            page.left,
                            0,
                            page.right,
                            AppSpacing.xl,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final r = results[index];
                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: AppSpacing.contentWidth(context),
                                ),
                                child: _SearchResultTile(result: r),
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

  List<Widget> _activeFilterChips(SearchQueryState state, WidgetRef ref) {
    final chips = <Widget>[];
    final notifier = ref.read(searchQueryProvider(_session).notifier);

    if (state.typeFilter != SearchResultFilter.all) {
      chips.add(
        InputChip(
          label: Text(state.typeFilter.label),
          onDeleted: () => notifier.setTypeFilter(SearchResultFilter.all),
        ),
      );
    }
    if (state.favoritesOnly) {
      chips.add(
        InputChip(
          label: const Text('Favorites only'),
          onDeleted: () => notifier.setFavoritesOnly(false),
        ),
      );
    }
    if (state.categoryId != null) {
      final cats = ref.watch(studyPinCategoriesProvider).valueOrNull;
      String? name;
      if (cats != null) {
        for (final c in cats) {
          if (c.id == state.categoryId) {
            name = c.name;
            break;
          }
        }
      }
      chips.add(
        InputChip(
          label: Text(name ?? 'Category'),
          onDeleted: () => notifier.setCategoryId(null),
        ),
      );
    }
    return chips;
  }
}

class _SearchFiltersSheet extends ConsumerWidget {
  const _SearchFiltersSheet({required this.categories, required this.session});
  final SearchSession session;

  final List<StudyPinCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchQueryProvider(session));
    final notifier = ref.read(searchQueryProvider(session).notifier);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filters', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text('Type', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final filter in SearchResultFilter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: state.typeFilter == filter,
                      onSelected: (_) => notifier.setTypeFilter(filter),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favorites only'),
                value: state.favoritesOnly,
                onChanged: notifier.setFavoritesOnly,
              ),
              if (state.typeFilter == SearchResultFilter.pins ||
                  state.typeFilter == SearchResultFilter.all) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Pin category', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: state.categoryId == null,
                      onSelected: (_) => notifier.setCategoryId(null),
                    ),
                    for (final cat in categories)
                      ChoiceChip(
                        label: Text(cat.name),
                        selected: state.categoryId == cat.id,
                        avatar: CircleAvatar(
                          backgroundColor: Color(cat.colorValue),
                          radius: 6,
                        ),
                        onSelected: (_) {
                          notifier.setCategoryId(
                            state.categoryId == cat.id ? null : cat.id,
                          );
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialSearchBody extends ConsumerWidget {
  const _InitialSearchBody({required this.theme, required this.scope});
  final StudySearchScope scope;

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (scope.kind != StudySearchScopeKind.library) {
      return EmptyState(
        icon: Icons.search,
        title: 'Search ${scope.title}',
        message:
            'Find lessons and matching text in PDFs, text files, saved AI materials, notes, and study pins. Tap a PDF match to open its page.',
      );
    }
    final favs = ref.watch(homeFavoritesProvider);
    final page = AppSpacing.pageInsets(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        page.left,
        AppSpacing.md,
        page.right,
        AppSpacing.xl,
      ),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppSpacing.contentWidth(context),
          ),
          child: Text(
            'Search lesson titles and text inside PDFs, Markdown files, saved AI materials, notes, and pins. PDF matches open on their page. Reference-book text is searchable after indexing the book in its reader.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        favs.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Favorites', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in items.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.star,
                        color: theme.colorScheme.tertiary,
                      ),
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
              ),
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
      tileColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      leading: Icon(_iconFor(result.kind), color: theme.colorScheme.primary),
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
        ].join(' · '),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
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
    StudyEntityKind.aiMaterial => Icons.auto_awesome,
    StudyEntityKind.courseReview => Icons.summarize_outlined,
    StudyEntityKind.book => Icons.menu_book_outlined,
  };
}
