import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/shelf.dart';
import '../repositories/shelf_repository.dart';

/// Use case for refreshing all shelves from server
@lazySingleton
class RefreshShelves {
  final ShelfRepository repository;

  RefreshShelves(this.repository);

  /// Refresh all shelves from server
  Future<Either<Failure, List<Shelf>>> call() async {
    return await repository.refreshShelves();
  }
}
