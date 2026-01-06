import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/search_query.dart';
import '../entities/search_result.dart';
import '../repositories/search_repository.dart';

/// Use case for searching books
@lazySingleton
class SearchBooks {
  final SearchRepository repository;

  SearchBooks(this.repository);

  /// Search for books on OpenLibrary
  Future<Either<Failure, SearchResult>> call({
    required SearchQuery query,
  }) async {
    if (query.query.trim().isEmpty) {
      return const Left(ValidationFailure('Search query cannot be empty'));
    }

    // Save query to history
    await repository.saveSearchQuery(query: query.query);

    return await repository.searchBooks(query: query);
  }
}
