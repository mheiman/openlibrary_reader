import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/book_list.dart';
import '../repositories/shelf_repository.dart';

/// Use case for getting user's book lists
@lazySingleton
class GetBookLists {
  final ShelfRepository repository;

  GetBookLists(this.repository);

  /// Get user's book lists from OpenLibrary
  Future<Either<Failure, List<BookList>>> call() async {
    return await repository.getBookLists();
  }
}
