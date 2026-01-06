import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

/// Reader repository interface
abstract class ReaderRepository {
  /// Get reader URL for Archive.org bookreader
  ///
  /// [bookId] - Edition ID or Archive.org identifier
  /// Returns reader URL or failure
  Future<Either<Failure, String>> getReaderUrl({
    required String bookId,
  });
}
