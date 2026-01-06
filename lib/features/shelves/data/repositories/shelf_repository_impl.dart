import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/logging_service.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_list.dart';
import '../../domain/entities/list_display_item.dart';
import '../../domain/entities/shelf.dart';
import '../../domain/repositories/shelf_repository.dart';
import '../datasources/shelf_local_data_source.dart';
import '../datasources/shelf_remote_data_source.dart';
import '../models/author_model.dart';
import '../models/book_model.dart';
import '../models/shelf_model.dart';

/// Implementation of [ShelfRepository]
@LazySingleton(as: ShelfRepository)
class ShelfRepositoryImpl extends BaseRepository implements ShelfRepository {
  final ShelfRemoteDataSource remoteDataSource;
  final ShelfLocalDataSource localDataSource;

  ShelfRepositoryImpl(this.remoteDataSource, this.localDataSource);

  @override
  Future<Either<Failure, List<Shelf>>> getShelves({
    bool forceRefresh = false,
  }) async {
    try {
      // Get configured shelf keys
      final shelfKeys = await localDataSource.getConfiguredShelfKeys();

      if (forceRefresh) {
        // Try to fetch from server, but fall back to cache on failure
        try {
          return await _fetchAndCacheShelves(shelfKeys);
        } catch (e) {
          // If server fetch fails, try to return cached data as fallback
          try {
            final cachedShelves = await localDataSource.getCachedShelves();
            final shelvesWithSort = await _applyStoredSortOrders(cachedShelves);
            LoggingService.info('getShelves() - returning ${cachedShelves.length} cached shelves as fallback');
            return Right(shelvesWithSort.map((s) => s.toEntity()).toList());
          } catch (cacheError) {
            // Both server and cache failed, rethrow original error
            rethrow;
          }
        }
      }

      // Try to get from cache first
      try {
        final cachedShelves = await localDataSource.getCachedShelves();
        LoggingService.trace('getShelves() - loaded ${cachedShelves.length} shelves from cache');

        // Return cached data with sort orders applied
        // Note: We no longer auto-refresh stale shelves here.
        // The UI will check staleness and refresh specific shelves as needed.
        final shelvesWithSort = await _applyStoredSortOrders(cachedShelves);
        return Right(shelvesWithSort.map((s) => s.toEntity()).toList());
      } on CacheException catch (e) {
        // No cache or cache error, fetch from server
        LoggingService.debug('getShelves() - CacheException: $e, fetching from server');
        return await _fetchAndCacheShelves(shelfKeys);
      }
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get shelves: $e'));
    }
  }

  @override
  Future<Either<Failure, Shelf>> getShelf({
    required String shelfKey,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        // Fetch just this shelf from server
        final shelfModel = await remoteDataSource.fetchSingleShelf(shelfKey: shelfKey);

        // Apply stored sort order
        final sortOrder = await localDataSource.getShelfSortOrder(shelfKey);
        final sortAscending = await localDataSource.getShelfSortAscending(shelfKey);
        final shelfWithSort = shelfModel.copyWith(
          sortOrder: sortOrder,
          sortAscending: sortAscending,
        );

        // Update cache
        await localDataSource.updateCachedShelf(shelfWithSort);

        return Right(shelfWithSort.toEntity());
      }

      // Try cache first
      try {
        final cachedShelf = await localDataSource.getCachedShelf(shelfKey);
        final shelfEntity = cachedShelf.toEntity();

        // Return cached shelf regardless of staleness
        // The UI will check staleness and trigger refresh if needed
        return Right(shelfEntity);
      } on CacheException {
        // No cache, fetch from server
        final shelfModel = await remoteDataSource.fetchSingleShelf(shelfKey: shelfKey);

        // Apply stored sort order
        final sortOrder = await localDataSource.getShelfSortOrder(shelfKey);
        final sortAscending = await localDataSource.getShelfSortAscending(shelfKey);
        final shelfWithSort = shelfModel.copyWith(
          sortOrder: sortOrder,
          sortAscending: sortAscending,
        );

        // Cache the shelf
        await localDataSource.updateCachedShelf(shelfWithSort);

        return Right(shelfWithSort.toEntity());
      }
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get shelf: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Shelf>>> refreshShelves() async {
    return await getShelves(forceRefresh: true);
  }

  @override
  Future<Either<Failure, void>> moveBookToShelf({
    required Book book,
    required String targetShelfKey,
  }) async {
    try {
      // If work ID is empty but we have an edition ID, we can't add to shelf
      // The bookshelves API requires a work ID
      if (book.workId.isEmpty) {
        if (book.editionId.isEmpty) {
          return const Left(ValidationFailure('Cannot add book to shelf: missing both work ID and edition ID'));
        }
        return const Left(ValidationFailure('Cannot add book to shelf: work ID is required. This book only has an edition ID.'));
      }

      // Call API to move book
      await remoteDataSource.moveBookToShelf(
        workId: book.workId,
        editionId: book.editionId,
        targetShelfKey: targetShelfKey,
      );

      // Update local cache
      try {
        final shelves = await localDataSource.getCachedShelves();

        // Remove book from all shelves
        final updatedShelves = shelves.map((shelf) {
          final filteredBooks = shelf.books
              .where((b) => b.workId != book.workId)
              .toList();
          final newTotalCount = (shelf.totalCount ?? shelf.books.length) -
                                (shelf.books.length - filteredBooks.length);
          return shelf.copyWith(
            books: filteredBooks,
            totalCount: newTotalCount,
          );
        }).toList();

        // Add book to target shelf
        final targetShelfIndex = updatedShelves.indexWhere(
          (s) => s.key == targetShelfKey,
        );

        if (targetShelfIndex != -1) {
          final targetShelf = updatedShelves[targetShelfIndex];
          final bookModel = ShelfModel.fromEntity(Shelf(
            key: '',
            name: '',
            olName: '',
            olId: 0,
            books: [book],
          )).books.first;

          final newTotalCount = (targetShelf.totalCount ?? targetShelf.books.length) + 1;
          updatedShelves[targetShelfIndex] = targetShelf.copyWith(
            books: [...targetShelf.books, bookModel],
            totalCount: newTotalCount,
          );
        }

        // Cache updated shelves
        await localDataSource.cacheShelves(updatedShelves);
      } catch (e) {
        // Cache update failed, but API call succeeded
        LoggingService.warning('Failed to update cache after moving book: $e');
      }

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to move book: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeBookFromShelf({
    required Book book,
    required String shelfKey,
  }) async {
    try {
      // Call API to remove book
      await remoteDataSource.removeBookFromShelf(workId: book.workId);

      // Update local cache
      try {
        final shelf = await localDataSource.getCachedShelf(shelfKey);
        final updatedBooks = shelf.books
            .where((b) => b.workId != book.workId)
            .toList();
        final newTotalCount = (shelf.totalCount ?? shelf.books.length) -
                              (shelf.books.length - updatedBooks.length);

        await localDataSource.updateCachedShelf(
          shelf.copyWith(
            books: updatedBooks,
            totalCount: newTotalCount,
          ),
        );
      } catch (e) {
        LoggingService.warning('Failed to update cache after removing book: $e');
      }

      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to remove book: $e'));
    }
  }

  @override
  Future<Either<Failure, Shelf>> updateShelfSort({
    required String shelfKey,
    required ShelfSortOrder sortOrder,
    required bool ascending,
  }) async {
    try {
      // Update sort order and direction in preferences
      await localDataSource.updateShelfSortOrder(shelfKey, sortOrder, ascending);

      // Get updated shelf
      final shelf = await localDataSource.getCachedShelf(shelfKey);
      final updatedShelf = shelf.copyWith(
        sortOrder: sortOrder,
        sortAscending: ascending,
      );

      // Update cache
      await localDataSource.updateCachedShelf(updatedShelf);

      return Right(updatedShelf.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update shelf sort: $e'));
    }
  }

  @override
  Future<Either<Failure, Shelf>> updateShelfVisibility({
    required String shelfKey,
    required bool isVisible,
  }) async {
    try {
      final shelf = await localDataSource.getCachedShelf(shelfKey);
      final updatedShelf = shelf.copyWith(isVisible: isVisible);

      await localDataSource.updateCachedShelf(updatedShelf);

      return Right(updatedShelf.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update shelf visibility: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      await localDataSource.clearCache();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to clear cache: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getConfiguredShelfKeys() async {
    try {
      final keys = await localDataSource.getConfiguredShelfKeys();
      return Right(keys);
    } catch (e) {
      return Left(UnknownFailure('Failed to get shelf keys: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateConfiguredShelfKeys({
    required List<String> shelfKeys,
  }) async {
    try {
      await localDataSource.updateConfiguredShelfKeys(shelfKeys);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update shelf keys: $e'));
    }
  }

  /// Helper: Fetch shelves from server and cache them
  Future<Either<Failure, List<Shelf>>> _fetchAndCacheShelves(
    List<String> shelfKeys,
  ) async {
    try {
      final shelves = await remoteDataSource.fetchShelves(shelfKeys: shelfKeys);

      // Apply stored sort orders
      final shelvesWithSort = await _applyStoredSortOrders(shelves);

      // Cache the shelves
      await localDataSource.cacheShelves(shelvesWithSort);

      return Right(shelvesWithSort.map((s) => s.toEntity()).toList());
    } catch (e) {
      rethrow;
    }
  }

  /// Helper: Apply stored sort orders to shelves
  Future<List<ShelfModel>> _applyStoredSortOrders(
    List<ShelfModel> shelves,
  ) async {
    final updatedShelves = <ShelfModel>[];

    for (var shelf in shelves) {
      final sortOrder = await localDataSource.getShelfSortOrder(shelf.key);
      final sortAscending = await localDataSource.getShelfSortAscending(shelf.key);
      updatedShelves.add(shelf.copyWith(
        sortOrder: sortOrder,
        sortAscending: sortAscending,
      ));
    }

    return updatedShelves;
  }

  @override
  Future<Either<Failure, List<BookList>>> getBookLists() async {
    try {
      final bookListModels = await remoteDataSource.fetchBookLists();
      final bookLists = bookListModels.map((model) => model.toEntity()).toList();
      return Right(bookLists);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get book lists: $e'));
    }
  }

  // Cache for user loans
  Map<String, dynamic>? _cachedLoans;
  DateTime? _loansTimestamp;
  static const _loansCacheDuration = Duration(hours: 1);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserLoans({
    bool forceRefresh = false,
  }) async {
    try {
      // Return cached data if available and not stale
      if (!forceRefresh &&
          _cachedLoans != null &&
          _loansTimestamp != null) {
        final age = DateTime.now().difference(_loansTimestamp!);
        if (age < _loansCacheDuration) {
          LoggingService.trace('getUserLoans() - returning cached data');
          return Right(_cachedLoans!);
        }
      }

      // Fetch fresh data from server
      LoggingService.debug('getUserLoans() - fetching from server');
      final loansMap = await remoteDataSource.fetchUserLoans();

      // Cache the data
      _cachedLoans = loansMap;
      _loansTimestamp = DateTime.now();

      return Right(loansMap);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get user loans: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ListDisplayItem>>> getListSeeds({
    required String listUrl,
    bool forceRefresh = false,
  }) async {
    try {
      // Try to get from cache first (unless force refresh)
      if (!forceRefresh) {
        final cached = await localDataSource.getCachedListItems(listUrl);
        if (cached != null) {
          final (books, authors, lastSynced) = cached;

          // Check if cache is still valid (within 6 hours)
          final now = DateTime.now();
          final cacheAge = now.difference(lastSynced);
          final isStale = cacheAge.inHours >= ApiConstants.cacheValidityHours;

          if (!isStale) {
            // Return cached items as display items
            final displayItems = <ListDisplayItem>[
              ...books.map((model) => BookDisplayItem(model.toEntity())),
              ...authors.map((model) => AuthorDisplayItem(model.toEntity())),
            ];
            return Right(displayItems);
          }
        }
      }

      // Fetch list seeds from API
      final seedModels = await remoteDataSource.fetchListSeeds(listUrl);

      // Separate seeds by type
      final bookSeeds = seedModels
          .where((seed) => seed.type == 'edition' || seed.type == 'work')
          .toList();
      final authorSeeds = seedModels
          .where((seed) => seed.type == 'author')
          .toList();

      // Fetch books and authors in parallel
      final results = await Future.wait([
        remoteDataSource.fetchBooksFromSeeds(bookSeeds),
        remoteDataSource.fetchAuthorsFromSeeds(authorSeeds),
      ]);

      final bookModels = results[0] as List<BookModel>;
      final authorModels = results[1] as List<AuthorModel>;

      // Cache both books and authors
      await localDataSource.cacheListItems(listUrl, bookModels, authorModels);

      // Convert to display items
      final displayItems = <ListDisplayItem>[
        ...bookModels.map((model) => BookDisplayItem(model.toEntity())),
        ...authorModels.map((model) => AuthorDisplayItem(model.toEntity())),
      ];

      return Right(displayItems);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get list seeds: $e'));
    }
  }
}
