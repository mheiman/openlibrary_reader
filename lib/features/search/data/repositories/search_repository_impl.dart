import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_local_data_source.dart';
import '../datasources/search_remote_data_source.dart';
import '../models/search_result_model.dart';

/// Implementation of search repository
@LazySingleton(as: SearchRepository)
class SearchRepositoryImpl extends BaseRepository implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final SearchLocalDataSource localDataSource;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, SearchResult>> searchBooks({
    required SearchQuery query,
  }) async {
    try {
      final result = await remoteDataSource.searchBooks(
        query: query.query,
        page: query.page,
        limit: query.limit,
        sort: query.sort,
      );

      return Right(result.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to search books: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSearches() async {
    try {
      final searches = await localDataSource.getRecentSearches();
      return Right(searches);
    } catch (e) {
      return Left(CacheFailure('Failed to get recent searches: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSearchQuery({
    required String query,
  }) async {
    try {
      await localDataSource.saveSearchQuery(query: query);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save search query: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSearchHistory() async {
    try {
      await localDataSource.clearSearchHistory();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to clear search history: ${e.toString()}'));
    }
  }
}
