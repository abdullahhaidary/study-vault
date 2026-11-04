import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../domain/study_search_result.dart';
import '../domain/study_search_scope.dart';
import 'file_search_indexer.dart';
import 'study_search_service.dart';

final studySearchServiceProvider = Provider<StudySearchService>(
  (ref) => StudySearchService(ref.watch(databaseProvider)),
);
final fileSearchIndexerProvider = Provider<FileSearchIndexer>((ref) {
  final indexer = FileSearchIndexer(ref.watch(databaseProvider));
  ref.onDispose(indexer.dispose);
  return indexer;
});
final fileSearchIndexProgressProvider = StreamProvider<FileSearchIndexProgress>(
  (ref) async* {
    final indexer = ref.watch(fileSearchIndexerProvider);
    yield indexer.progress;
    yield* indexer.changes;
  },
);
final _searchMaterialChangesProvider = StreamProvider.autoDispose<void>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.lessonMaterials, db.lessons, db.subjects},
      )
      .watch()
      .map((_) {});
});
final fileSearchIndexRequestProvider = FutureProvider.autoDispose
    .family<void, StudySearchScope>((ref, scope) {
      ref.watch(_searchMaterialChangesProvider);
      return ref.watch(fileSearchIndexerProvider).ensureIndexed(scope);
    });

/// Each search screen has its own query and filters, even while another search
/// route remains mounted below it.
class SearchSession {
  SearchSession({
    this.scope = const StudySearchScope.library(),
    this.filter = SearchResultFilter.all,
  });
  final StudySearchScope scope;
  final SearchResultFilter filter;
}

class SearchQueryState {
  const SearchQueryState({
    this.query = '',
    this.typeFilter = SearchResultFilter.all,
    this.categoryId,
    this.favoritesOnly = false,
    this.scope = const StudySearchScope.library(),
  });
  final String query;
  final SearchResultFilter typeFilter;
  final String? categoryId;
  final bool favoritesOnly;
  final StudySearchScope scope;
  SearchQueryState copyWith({
    String? query,
    SearchResultFilter? typeFilter,
    String? categoryId,
    bool clearCategory = false,
    bool? favoritesOnly,
    StudySearchScope? scope,
  }) => SearchQueryState(
    query: query ?? this.query,
    typeFilter: typeFilter ?? this.typeFilter,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    scope: scope ?? this.scope,
  );
}

class SearchQueryNotifier extends StateNotifier<SearchQueryState> {
  SearchQueryNotifier([super.initial = const SearchQueryState()]);
  void setQuery(String value) => state = state.copyWith(query: value);
  void setTypeFilter(SearchResultFilter value) =>
      state = state.copyWith(typeFilter: value);
  void setCategoryId(String? value) =>
      state = state.copyWith(categoryId: value, clearCategory: value == null);
  void setFavoritesOnly(bool value) =>
      state = state.copyWith(favoritesOnly: value);
  void setScope(StudySearchScope value) => state = state.copyWith(scope: value);
}

final searchQueryProvider = StateNotifierProvider.autoDispose
    .family<SearchQueryNotifier, SearchQueryState, SearchSession>(
      (ref, session) => SearchQueryNotifier(
        SearchQueryState(scope: session.scope, typeFilter: session.filter),
      ),
    );
final _debouncedSearchProvider = FutureProvider.autoDispose
    .family<SearchQueryState, SearchSession>((ref, session) async {
      final state = ref.watch(searchQueryProvider(session));
      if (state.query.trim().isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return state;
    });
final _searchLibraryChangesProvider = StreamProvider.autoDispose<void>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.classes,
          db.subjects,
          db.lessons,
          db.lessonMaterials,
          db.studyPins,
          db.studyNotes,
          db.flashcards,
          db.materialBookmarks,
          db.favorites,
          db.pdfAiMaterials,
          db.courseReviewEntries,
          db.referenceBooks,
          db.referenceBookSubjects,
          db.referenceBookLinks,
        },
      )
      .watch()
      .map((_) {});
});
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<StudySearchResult>, SearchSession>((ref, session) async {
      final pendingQuery = ref.watch(_debouncedSearchProvider(session).future);
      final service = ref.watch(studySearchServiceProvider);
      // Index updates refresh matches without restarting the typing debounce.
      ref.watch(fileSearchIndexProgressProvider);
      ref.watch(_searchLibraryChangesProvider);
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final state = await pendingQuery;
      if (disposed || state.query.trim().isEmpty) return [];
      return service.search(
        query: state.query,
        typeFilter: state.typeFilter,
        categoryId: state.categoryId,
        favoritesOnly: state.favoritesOnly,
        scope: state.scope,
      );
    });
