import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/shelf.dart';
import '../repositories/shelf_repository.dart';

/// Use case for updating shelf sort order
@lazySingleton
class UpdateShelfSort {
  final ShelfRepository repository;

  UpdateShelfSort(this.repository);

  /// Update shelf sort order
  ///
  /// [shelfKey] - Shelf to update
  /// [sortOrder] - New sort order
  /// [ascending] - Sort direction (true = ascending, false = descending)
  Future<Either<Failure, Shelf>> call({
    required String shelfKey,
    required ShelfSortOrder sortOrder,
    required bool ascending,
  }) async {
    if (shelfKey.isEmpty) {
      return const Left(ValidationFailure('Shelf key cannot be empty'));
    }

    return await repository.updateShelfSort(
      shelfKey: shelfKey,
      sortOrder: sortOrder,
      ascending: ascending,
    );
  }
}
