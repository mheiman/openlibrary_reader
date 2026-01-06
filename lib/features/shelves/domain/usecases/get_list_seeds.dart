import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/list_display_item.dart';
import '../repositories/shelf_repository.dart';

/// Use case for fetching and converting list seeds to display items
@lazySingleton
class GetListSeeds {
  final ShelfRepository repository;

  GetListSeeds(this.repository);

  /// Get display items from a list
  ///
  /// Fetches list seeds and converts them to display items (books, authors, etc.)
  /// Supports edition, work, and author seeds
  /// [forceRefresh] - Force fetch from server, ignoring cache
  /// Returns failure if fetching fails
  Future<Either<Failure, List<ListDisplayItem>>> call({
    required String listUrl,
    bool forceRefresh = false,
  }) async {
    return await repository.getListSeeds(
      listUrl: listUrl,
      forceRefresh: forceRefresh,
    );
  }
}
