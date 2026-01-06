import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/book.dart';
import '../entities/book_list.dart';
import '../entities/list_display_item.dart';
import '../entities/shelf.dart';

/// Shelf repository interface
abstract class ShelfRepository {
  /// Get all shelves for the current user
  ///
  /// [forceRefresh] - Force refresh from server instead of using cache
  /// Returns list of shelves or failure
  Future<Either<Failure, List<Shelf>>> getShelves({
    bool forceRefresh = false,
  });

  /// Get a specific shelf by key
  ///
  /// [shelfKey] - Shelf identifier (e.g., 'currently-reading')
  /// [forceRefresh] - Force refresh from server
  /// Returns shelf or failure
  Future<Either<Failure, Shelf>> getShelf({
    required String shelfKey,
    bool forceRefresh = false,
  });

  /// Refresh all shelves from server
  ///
  /// Returns updated list of shelves or failure
  Future<Either<Failure, List<Shelf>>> refreshShelves();

  /// Move a book to a different shelf
  ///
  /// [book] - Book to move
  /// [targetShelfKey] - Key of destination shelf
  /// Returns success or failure
  Future<Either<Failure, void>> moveBookToShelf({
    required Book book,
    required String targetShelfKey,
  });

  /// Remove a book from a shelf
  ///
  /// [book] - Book to remove
  /// [shelfKey] - Shelf to remove from
  /// Returns success or failure
  Future<Either<Failure, void>> removeBookFromShelf({
    required Book book,
    required String shelfKey,
  });

  /// Update shelf sort order
  ///
  /// [shelfKey] - Shelf to update
  /// [sortOrder] - New sort order
  /// [ascending] - Sort direction (true = ascending, false = descending)
  /// Returns updated shelf or failure
  Future<Either<Failure, Shelf>> updateShelfSort({
    required String shelfKey,
    required ShelfSortOrder sortOrder,
    required bool ascending,
  });

  /// Update shelf visibility
  ///
  /// [shelfKey] - Shelf to update
  /// [isVisible] - Visibility flag
  /// Returns updated shelf or failure
  Future<Either<Failure, Shelf>> updateShelfVisibility({
    required String shelfKey,
    required bool isVisible,
  });

  /// Clear all cached shelf data
  ///
  /// Returns success or failure
  Future<Either<Failure, void>> clearCache();

  /// Get list of configured shelf keys
  ///
  /// Returns list of shelf keys from settings
  Future<Either<Failure, List<String>>> getConfiguredShelfKeys();

  /// Update configured shelf keys
  ///
  /// [shelfKeys] - List of shelf keys to configure
  /// Returns success or failure
  Future<Either<Failure, void>> updateConfiguredShelfKeys({
    required List<String> shelfKeys,
  });

  /// Get user's book lists from OpenLibrary
  ///
  /// Returns list of book lists or failure
  Future<Either<Failure, List<BookList>>> getBookLists();

  /// Get user's current book loans from OpenLibrary
  ///
  /// [forceRefresh] - Force refresh from server instead of using cache
  /// Returns map of edition ID to loan data, or failure
  Future<Either<Failure, Map<String, dynamic>>> getUserLoans({
    bool forceRefresh = false,
  });

  /// Get seeds (items) from a specific list
  ///
  /// [listUrl] - URL of the list (e.g., "/people/username/lists/OL123L")
  /// [forceRefresh] - Force fetch from server, ignoring cache
  /// Returns list of display items (books, authors, subjects) converted from seeds
  /// Supports edition, work, and author seeds
  Future<Either<Failure, List<ListDisplayItem>>> getListSeeds({
    required String listUrl,
    bool forceRefresh = false,
  });
}
