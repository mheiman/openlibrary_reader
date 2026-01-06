import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/search_query.dart';
import '../../domain/usecases/get_recent_searches.dart';
import '../../domain/usecases/search_books.dart';
import 'search_state.dart';

/// Search state notifier
@injectable
class SearchNotifier extends ChangeNotifier {
  final SearchBooks searchBooks;
  final GetRecentSearches getRecentSearches;

  SearchNotifier({
    required this.searchBooks,
    required this.getRecentSearches,
  });

  SearchState _state = const SearchInitial();

  SearchState get state => _state;

  void _setState(SearchState state) {
    _state = state;
    notifyListeners();
  }

  /// Load recent searches
  Future<void> loadRecentSearches() async {
    final result = await getRecentSearches();

    result.fold(
      (failure) => _setState(SearchError(failure.message)),
      (searches) => _setState(RecentSearchesLoaded(searches)),
    );
  }

  /// Search for books
  Future<void> search(String query) async {
    await searchWithSort(query, null);
  }

  /// Search for books with sort parameter
  Future<void> searchWithSort(String query, String? sort) async {
    if (query.trim().isEmpty) {
      _setState(const SearchError('Search query cannot be empty'));
      return;
    }

    _setState(const SearchLoading());

    final searchQuery = SearchQuery(
      query: query,
      limit: 100, // Load 100 results per page
      sort: sort,
    );
    final result = await searchBooks(query: searchQuery);

    result.fold(
      (failure) => _setState(SearchError(failure.message)),
      (searchResult) => _setState(SearchLoaded(
        result: searchResult,
        currentQuery: query,
        currentSort: sort,
      )),
    );
  }

  /// Load more results (pagination)
  Future<void> loadMore() async {
    if (_state is! SearchLoaded) return;

    final currentState = _state as SearchLoaded;
    if (!currentState.result.hasMore) return;

    _setState(const SearchLoading(isLoadingMore: true));

    final searchQuery = SearchQuery(
      query: currentState.currentQuery,
      page: currentState.result.currentPage + 1,
      limit: 100, // Load 100 results per page
      sort: currentState.currentSort,
    );

    final result = await searchBooks(query: searchQuery);

    result.fold(
      (failure) => _setState(SearchError(failure.message)),
      (searchResult) {
        // Combine previous and new results
        final combinedWorks = [
          ...currentState.result.works,
          ...searchResult.works,
        ];

        final combinedResult = searchResult.copyWith(works: combinedWorks);

        _setState(SearchLoaded(
          result: combinedResult,
          currentQuery: currentState.currentQuery,
          currentSort: currentState.currentSort,
        ));
      },
    );
  }

  /// Clear search and show recent searches
  void clearSearch() {
    loadRecentSearches();
  }
}
