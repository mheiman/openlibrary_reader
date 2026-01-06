import 'package:equatable/equatable.dart';

/// Search query parameters
class SearchQuery extends Equatable {
  final String query;
  final int page;
  final int limit;
  final bool hasFulltext; // Only show books with ebooks
  final String? sort; // Sort parameter for API

  const SearchQuery({
    required this.query,
    this.page = 1,
    this.limit = 20,
    this.hasFulltext = true,
    this.sort,
  });

  @override
  List<Object?> get props => [query, page, limit, hasFulltext, sort];

  /// Copy with updated fields
  SearchQuery copyWith({
    String? query,
    int? page,
    int? limit,
    bool? hasFulltext,
    String? sort,
  }) {
    return SearchQuery(
      query: query ?? this.query,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasFulltext: hasFulltext ?? this.hasFulltext,
      sort: sort ?? this.sort,
    );
  }

  /// Create next page query
  SearchQuery nextPage() {
    return copyWith(page: page + 1);
  }

  /// Reset to first page
  SearchQuery resetPage() {
    return copyWith(page: 1);
  }
}
