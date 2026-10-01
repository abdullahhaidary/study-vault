import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../domain/study_search_result.dart';
import 'study_search_service.dart';

final studySearchServiceProvider = Provider<StudySearchService>((ref) {
  return StudySearchService(ref.watch(databaseProvider));
});

class SearchQueryState {
  const SearchQueryState({
    this.query = '',
    this.typeFilter = SearchResultFilter.all,
    this.categoryId,
    this.favoritesOnly = false,
  });

  final String query;
  final SearchResultFilter typeFilter;
  final String? categoryId;
  final bool favoritesOnly;

  SearchQueryState copyWith({
    String? query,
    SearchResultFilter? typeFilter,
    String? categoryId,
    bool clearCategory = false,
    bool? favoritesOnly,
  }) {
    return SearchQueryState(
      query: query ?? this.query,
      typeFilter: typeFilter ?? this.typeFilter,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class SearchQueryNotifier extends StateNotifier<SearchQueryState> {
  SearchQueryNotifier() : super(const SearchQueryState());

  void setQuery(String value) => state = state.copyWith(query: value);

  void setTypeFilter(SearchResultFilter filter) =>
      state = state.copyWith(typeFilter: filter);

  void setCategoryId(String? id) =>
      state = state.copyWith(categoryId: id, clearCategory: id == null);

  void setFavoritesOnly(bool value) =>
      state = state.copyWith(favoritesOnly: value);
}

final searchQueryProvider =
    StateNotifierProvider.autoDispose<SearchQueryNotifier, SearchQueryState>(
      (ref) => SearchQueryNotifier(),
    );

/// Debounced search results (~300ms).
final searchResultsProvider =
    StreamProvider.autoDispose<List<StudySearchResult>>((ref) async* {
      final queryState = ref.watch(searchQueryProvider);
      final service = ref.watch(studySearchServiceProvider);

      if (queryState.query.trim().isEmpty) {
        yield const [];
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      yield await service.search(
        query: queryState.query,
        typeFilter: queryState.typeFilter,
        categoryId: queryState.categoryId,
        favoritesOnly: queryState.favoritesOnly,
      );
    });
