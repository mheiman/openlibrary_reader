import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/edition.dart';
import '../repositories/book_details_repository.dart';

/// Use case for getting available editions
@lazySingleton
class GetEditions {
  final BookDetailsRepository repository;

  GetEditions(this.repository);

  /// Get all editions for a work
  Future<Either<Failure, List<Edition>>> call({
    required String workId,
  }) async {
    if (workId.isEmpty) {
      return const Left(ValidationFailure('Work ID cannot be empty'));
    }

    return await repository.getEditions(workId: workId);
  }
}
