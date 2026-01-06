import '../../domain/entities/search_result.dart';

/// Base search state
abstract class SearchState {
  const SearchState();
}

/// Initial state
class SearchInitial extends SearchState {
  const SearchInitial();
}

/// Searching state
class SearchLoading extends SearchState {
  final bool isLoadingMore;

  const SearchLoading({this.isLoadingMore = false});
}

/// Search results loaded state
class SearchLoaded extends SearchState {
  final SearchResult result;
  final String currentQuery;
  final String? currentSort;

  const SearchLoaded({
    required this.result,
    required this.currentQuery,
    this.currentSort,
  });

  /// Copy with updated fields
  SearchLoaded copyWith({
    SearchResult? result,
    String? currentQuery,
    String? currentSort,
  }) {
    return SearchLoaded(
      result: result ?? this.result,
      currentQuery: currentQuery ?? this.currentQuery,
      currentSort: currentSort ?? this.currentSort,
    );
  }
}

/// Search error state
class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);
}

/// Recent searches loaded state
class RecentSearchesLoaded extends SearchState {
  final List<String> searches;

  const RecentSearchesLoaded(this.searches);
}
