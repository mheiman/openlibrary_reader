import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/search_query.dart';
import '../entities/search_result.dart';

/// Search repository interface
abstract class SearchRepository {
  /// Search for books
  ///
  /// [query] - Search query parameters
  /// Returns search results or failure
  Future<Either<Failure, SearchResult>> searchBooks({
    required SearchQuery query,
  });

  /// Get recent searches
  ///
  /// Returns list of recent search queries
  Future<Either<Failure, List<String>>> getRecentSearches();

  /// Save search query to history
  ///
  /// [query] - Query to save
  /// Returns success or failure
  Future<Either<Failure, void>> saveSearchQuery({
    required String query,
  });

  /// Clear search history
  ///
  /// Returns success or failure
  Future<Either<Failure, void>> clearSearchHistory();
}
