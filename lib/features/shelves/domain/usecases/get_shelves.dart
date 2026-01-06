import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/shelf.dart';
import '../repositories/shelf_repository.dart';

/// Use case for getting all shelves
@lazySingleton
class GetShelves {
  final ShelfRepository repository;

  GetShelves(this.repository);

  /// Get all shelves
  ///
  /// [forceRefresh] - Force refresh from server instead of using cache
  Future<Either<Failure, List<Shelf>>> call({
    bool forceRefresh = false,
  }) async {
    return await repository.getShelves(forceRefresh: forceRefresh);
  }
}
