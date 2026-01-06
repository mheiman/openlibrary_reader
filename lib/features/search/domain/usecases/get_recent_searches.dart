import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/search_repository.dart';

/// Use case for getting recent searches
@lazySingleton
class GetRecentSearches {
  final SearchRepository repository;

  GetRecentSearches(this.repository);

  /// Get recent search queries
  Future<Either<Failure, List<String>>> call() async {
    return await repository.getRecentSearches();
  }
}
