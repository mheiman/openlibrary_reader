import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/book_details.dart';
import '../../domain/entities/edition.dart';
import '../../domain/repositories/book_details_repository.dart';
import '../datasources/book_details_remote_data_source.dart';

/// Implementation of [BookDetailsRepository]
@LazySingleton(as: BookDetailsRepository)
class BookDetailsRepositoryImpl extends BaseRepository implements BookDetailsRepository {
  final BookDetailsRemoteDataSource remoteDataSource;

  BookDetailsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, BookDetails>> getBookDetails({
    required String editionId,
  }) async {
    try {
      final bookDetailsModel = await remoteDataSource.fetchBookDetails(
        editionId: editionId,
      );
      return Right(bookDetailsModel.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get book details: $e'));
    }
  }

  @override
  Future<Either<Failure, BookDetails>> getBookDetailsByWork({
    required String workId,
  }) async {
    // Get editions first, then get details for the first available edition
    try {
      final editionsResult = await getEditions(workId: workId);
      return editionsResult.fold(
        (failure) => Left(failure),
        (editions) async {
          if (editions.isEmpty) {
            return const Left(NotFoundFailure('No editions found for this work'));
          }

          // Get details for the first edition
          return await getBookDetails(editionId: editions.first.editionId);
        },
      );
    } catch (e) {
      return Left(UnknownFailure('Failed to get book details by work: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Edition>>> getEditions({
    required String workId,
  }) async {
    try {
      final editionModels = await remoteDataSource.fetchEditions(
        workId: workId,
      );
      return Right(editionModels.map((m) => m.toEntity()).toList());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get editions: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> borrowBook({
    required String editionId,
    String loanType = '1hour',
  }) async {
    try {
      await remoteDataSource.borrowBook(
        editionId: editionId,
        loanType: loanType,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to borrow book: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> returnBook({
    required String editionId,
  }) async {
    try {
      await remoteDataSource.returnBook(editionId: editionId);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to return book: $e'));
    }
  }

  @override
  Future<Either<Failure, List<BookDetails>>> getRelatedBooks({
    required String workId,
  }) async {
    // This would require additional API implementation
    // For now, return empty list
    return const Right([]);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBorrowStatus({
    required String editionId,
  }) async {
    try {
      final status = await remoteDataSource.getBorrowStatus(
        editionId: editionId,
      );
      return Right(status);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get borrow status: $e'));
    }
  }
}
