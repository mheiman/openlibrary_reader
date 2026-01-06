import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/book_details.dart';
import '../entities/edition.dart';

/// Book details repository interface
abstract class BookDetailsRepository {
  /// Get detailed book information
  ///
  /// [editionId] - Edition OLID (e.g., OL24381194M)
  /// Returns book details or failure
  Future<Either<Failure, BookDetails>> getBookDetails({
    required String editionId,
  });

  /// Get book details by work ID
  ///
  /// [workId] - Work ID (e.g., OL472814W)
  /// Returns book details or failure
  Future<Either<Failure, BookDetails>> getBookDetailsByWork({
    required String workId,
  });

  /// Get available editions for a work
  ///
  /// [workId] - Work ID
  /// Returns list of editions or failure
  Future<Either<Failure, List<Edition>>> getEditions({
    required String workId,
  });

  /// Borrow a book
  ///
  /// [editionId] - Edition to borrow
  /// [loanType] - '1hour' or '14day'
  /// Returns success or failure
  Future<Either<Failure, void>> borrowBook({
    required String editionId,
    String loanType = '1hour',
  });

  /// Return a borrowed book
  ///
  /// [editionId] - Edition to return
  /// Returns success or failure
  Future<Either<Failure, void>> returnBook({
    required String editionId,
  });

  /// Get related books/works
  ///
  /// [workId] - Work ID
  /// Returns list of related book details or failure
  Future<Either<Failure, List<BookDetails>>> getRelatedBooks({
    required String workId,
  });

  /// Check current borrow status
  ///
  /// [editionId] - Edition to check
  /// Returns borrow status or failure
  Future<Either<Failure, Map<String, dynamic>>> getBorrowStatus({
    required String editionId,
  });
}
