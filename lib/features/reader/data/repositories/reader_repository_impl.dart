import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/reader_repository.dart';
import '../datasources/reader_remote_data_source.dart';

/// Implementation of [ReaderRepository]
@LazySingleton(as: ReaderRepository)
class ReaderRepositoryImpl extends BaseRepository implements ReaderRepository {
  final ReaderRemoteDataSource remoteDataSource;

  ReaderRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, String>> getReaderUrl({
    required String bookId,
  }) async {
    try {
      final url = await remoteDataSource.getReaderUrl(bookId: bookId);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get reader URL: $e'));
    }
  }
}
