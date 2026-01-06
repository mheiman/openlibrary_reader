import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/reader_repository.dart';

/// Use case for getting reader URL
@lazySingleton
class GetReaderUrl {
  final ReaderRepository repository;

  GetReaderUrl(this.repository);

  /// Get reader URL for Archive.org bookreader
  Future<Either<Failure, String>> call({
    required String bookId,
  }) async {
    if (bookId.isEmpty) {
      return const Left(ValidationFailure('Book ID cannot be empty'));
    }

    return await repository.getReaderUrl(bookId: bookId);
  }
}
