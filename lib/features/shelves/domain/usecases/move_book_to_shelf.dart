import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/book.dart';
import '../repositories/shelf_repository.dart';

/// Use case for moving a book to a different shelf
@lazySingleton
class MoveBookToShelf {
  final ShelfRepository repository;

  MoveBookToShelf(this.repository);

  /// Move book to target shelf
  ///
  /// [book] - Book to move
  /// [targetShelfKey] - Key of destination shelf
  Future<Either<Failure, void>> call({
    required Book book,
    required String targetShelfKey,
  }) async {
    if (targetShelfKey.isEmpty) {
      return const Left(ValidationFailure('Target shelf key cannot be empty'));
    }

    return await repository.moveBookToShelf(
      book: book,
      targetShelfKey: targetShelfKey,
    );
  }
}
