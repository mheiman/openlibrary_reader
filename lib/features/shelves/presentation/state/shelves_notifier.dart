import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'dart:async';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/visual_adjustments_service.dart';
import '../../../authentication/presentation/state/auth_notifier.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../book_details/data/datasources/book_details_remote_data_source.dart';
import '../../data/datasources/shelf_remote_data_source.dart';
import '../../data/repositories/shelf_repository_impl.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/shelf.dart';
import '../../domain/repositories/shelf_repository.dart';
import '../../domain/usecases/get_book_lists.dart';
import '../../domain/usecases/get_list_seeds.dart';
import '../../domain/usecases/get_shelves.dart';
import '../../domain/usecases/move_book_to_shelf.dart';
import '../../domain/usecases/refresh_shelves.dart';
import '../../domain/usecases/update_shelf_sort.dart';
import 'shelves_state.dart';

/// Shelves state notifier
@lazySingleton
class ShelvesNotifier extends ChangeNotifier {
  final GetShelves getShelvesUseCase;
  final GetBookLists getBookListsUseCase;
  final GetListSeeds getListSeedsUseCase;
  final RefreshShelves refreshShelvesUseCase;
  final MoveBookToShelf moveBookToShelfUseCase;
  final UpdateShelfSort updateShelfSortUseCase;
  final ShelfRepository repository;
  final BookDetailsRemoteDataSource bookDetailsDataSource;
  final ShelfRemoteDataSource shelfRemoteDataSource;
  final AuthNotifier authNotifier;
  final VisualAdjustmentsService visualAdjustmentsService;

  ShelvesState _state = const ShelvesInitial();
  ShelvesState get state => _state;

  AuthState? _previousAuthState;

  /// Map of edition ID to loan data
  Map<String, dynamic> _userLoans = {};

  /// Track which shelves are currently being refreshed to prevent race conditions
  final Set<String> _refreshingShelves = {};

  /// Queue for pending refresh requests
  final List<String> _refreshQueue = [];

  /// Timer for processing refresh queue
  Timer? _refreshQueueTimer;

  /// Track if the notifier is disposed to prevent operations on disposed objects
  bool _isDisposed = false;

  ShelvesNotifier({
    required this.getShelvesUseCase,
    required this.getBookListsUseCase,
    required this.getListSeedsUseCase,
    required this.refreshShelvesUseCase,
    required this.moveBookToShelfUseCase,
    required this.updateShelfSortUseCase,
    required this.repository,
    required this.bookDetailsDataSource,
    required this.shelfRemoteDataSource,
    required this.authNotifier,
    required this.visualAdjustmentsService,
  }) {
    // Listen to auth state changes to detect login
    authNotifier.addListener(_syncAuthStateChanged);
    _previousAuthState = authNotifier.state;
  }

  /// Check if the notifier is disposed and throw an exception if so
  void _checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot perform operations on a disposed ShelvesNotifier');
    }
  }

  /// Synchronous wrapper for auth state changes to handle async operations safely
  void _syncAuthStateChanged() {
    // Schedule the async operation to run after the current event loop completes
    // This prevents blocking the UI and allows the ChangeNotifier to complete its cycle
    Future.microtask(() => _onAuthStateChanged());
  }

  @override
  void dispose() {
    LoggingService.debug('ShelvesNotifier: dispose() called');
    
    // Mark as disposed to prevent any further operations
    _isDisposed = true;
    
    // Remove auth listener
    authNotifier.removeListener(_syncAuthStateChanged);
    
    // Clean up refresh queue resources
    _refreshQueueTimer?.cancel();
    _refreshQueue.clear();
    _refreshingShelves.clear();
    
    // Clear any in-memory data to help with garbage collection
    _userLoans.clear();
    
    LoggingService.debug('ShelvesNotifier: dispose() completed');
    
    super.dispose();
  }

  /// Update state and notify listeners
  void _emit(ShelvesState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Track if we're currently processing an auth state change to prevent re-entrancy
  bool _isProcessingAuthChange = false;

  /// Handle auth state changes - refresh all shelves on new login, clear on logout
  Future<void> _onAuthStateChanged() async {
    // Check if disposed before processing
    if (_isDisposed) {
      LoggingService.debug('ShelvesNotifier: Ignoring auth state change - notifier is disposed');
      return;
    }

    // Prevent re-entrant calls that could cause race conditions
    if (_isProcessingAuthChange) {
      LoggingService.debug('ShelvesNotifier: Ignoring auth state change - already processing');
      return;
    }

    try {
      _isProcessingAuthChange = true;
      final currentState = authNotifier.state;
      final previousState = _previousAuthState;

      LoggingService.debug('ShelvesNotifier: Auth state changed from $previousState to $currentState');

      // Clear shelf data on logout: AuthLoading → Unauthenticated
      if (previousState is AuthLoading && currentState is Unauthenticated) {
        LoggingService.debug('ShelvesNotifier: Handling logout - clearing shelf data');
        await _clearShelfDataAndCache();
      }
      // Clear cache when login starts: Unauthenticated → AuthLoading
      // This ensures old user's cached data is cleared before new user's data loads
      else if (previousState is Unauthenticated && currentState is AuthLoading) {
        LoggingService.debug('ShelvesNotifier: Login started - clearing cache');
        await _clearShelfDataAndCache();
      }
      // Refresh on explicit login: AuthLoading → Authenticated
      // (Login goes through AuthLoading state: Unauthenticated → AuthLoading → Authenticated)
      else if (previousState is AuthLoading && currentState is Authenticated) {
        LoggingService.debug('ShelvesNotifier: Login completed - refreshing shelves');
        await loadShelves(forceRefresh: true);
      }
      // On app startup: AuthInitial → Authenticated, load shelves if not already loaded
      else if (previousState is AuthInitial && currentState is Authenticated) {
        if (_state is! ShelvesLoaded) {
          LoggingService.debug('ShelvesNotifier: App startup with authenticated user - loading shelves');
          await loadShelves();
        }
      }

      // Only update previous state if we successfully processed the change
      _previousAuthState = currentState;
    } catch (e, stackTrace) {
      LoggingService.error('ShelvesNotifier: Error processing auth state change', e, stackTrace);
      // Don't update previous state on error to allow retry
    } finally {
      _isProcessingAuthChange = false;
    }
  }

  /// Clear shelf data and cache on logout
  Future<void> _clearShelfDataAndCache() async {
    // Clear in-memory state first
    _emit(const ShelvesInitial());
    _userLoans = {};

    // Clear shelf cache
    await repository.clearCache();
  }

  /// Load shelves (from cache or server)
  Future<void> loadShelves({bool forceRefresh = false}) async {
    _checkNotDisposed();
    
    // Don't load if user is not authenticated (logged out)
    final authState = authNotifier.state;
    if (authState is Unauthenticated) {
      return;
    }

    // If we already have loaded shelves, keep showing them while refreshing
    if (_state is ShelvesLoaded) {
      final currentState = _state as ShelvesLoaded;
      _emit(ShelvesLoaded(
        currentState.shelves,
        bookLists: currentState.bookLists,
        isRefreshing: true,
      ));
    } else {
      // First time loading - show loading state
      _emit(const ShelvesLoading());
    }

    // Determine if we need to fetch book lists
    final currentBookLists = _state is ShelvesLoaded
        ? (_state as ShelvesLoaded).bookLists
        : <dynamic>[];
    final shouldFetchLists = forceRefresh || currentBookLists.isEmpty;

    // If force refresh and no cache, use progressive loading for better UX
    if (forceRefresh && _state is! ShelvesLoaded) {
      await _loadShelvesProgressively(shouldFetchLists);
      return;
    }

    // Fetch shelves and optionally book lists
    final futures = <Future>[
      getShelvesUseCase(forceRefresh: forceRefresh),
      if (shouldFetchLists) getBookListsUseCase(),
    ];

    final results = await Future.wait(futures);

    final shelvesResult = results[0];
    final bookListsResult = shouldFetchLists && results.length > 1
        ? results[1]
        : Right(currentBookLists);

    // Handle results
    if (shelvesResult.isLeft()) {
      final failure = (shelvesResult as Left).value as Failure;

      // If it's an auth failure, don't show error - router will redirect to login
      if (failure is AuthFailure || failure is UnauthorizedFailure) {
        LoggingService.error('DEBUG: loadShelves() - auth failure detected, router will handle redirect');
        // Keep current state or show initial state, don't show error
        if (_state is! ShelvesLoaded) {
          _emit(const ShelvesInitial());
        }
        return;
      }

      // Special handling for force refresh failures
      // This can happen after login when we need fresh data but server request fails
      if (forceRefresh) {
        LoggingService.error('ShelvesNotifier: Force refresh failed during login - $failure');
        LoggingService.error('ShelvesNotifier: This should not happen after login, retrying...');
        
        // Show loading state while we retry
        _emit(const ShelvesLoading());
        
        // Try one more time after a brief delay
        try {
          await Future.delayed(const Duration(seconds: 1));
          final retryResult = await getShelvesUseCase(forceRefresh: true);
          
          if (retryResult.isRight()) {
            final shelves = (retryResult as Right).value as List<Shelf>;
            LoggingService.debug('ShelvesNotifier: Retry successful, loaded ${shelves.length} shelves');
            
            final bookLists = bookListsResult.isRight()
                ? (bookListsResult as Right).value as List
                : <dynamic>[];
            
            _emit(ShelvesLoaded(
              shelves,
              bookLists: bookLists.cast(),
            ));
            
            // Restore persisted list selection if book lists were loaded
            if (bookLists.isNotEmpty) {
              _restorePersistedListSelection();
            }
            return;
          } else {
            // If retry fails, show error
            final retryFailure = (retryResult as Left).value as Failure;
            LoggingService.error('ShelvesNotifier: Retry also failed - ${retryFailure.message}');
            _emit(ShelvesError('Failed to load shelves after login. Please try refreshing.'));
            return;
          }
        } catch (retryError) {
          LoggingService.error('ShelvesNotifier: Exception during retry: $retryError');
          _emit(ShelvesError('Failed to load shelves. Please check your connection.'));
          return;
        }
      }

      // If we had stale data, keep it and just clear refreshing flag
      if (_state is ShelvesLoaded) {
        final currentState = _state as ShelvesLoaded;
        _emit(ShelvesLoaded(
          currentState.shelves,
          bookLists: currentState.bookLists,
          isRefreshing: false,
        ));
      } else {
        // Last resort: try to load from cache directly (only when not force refreshing)
        LoggingService.error('DEBUG: loadShelves() - error and no loaded state, trying cache as last resort');
        final cacheResult = await repository.getShelves(forceRefresh: false);
        if (cacheResult.isRight()) {
          final shelves = (cacheResult as Right).value as List<Shelf>;
          LoggingService.error('DEBUG: loadShelves() - recovered ${shelves.length} shelves from cache');
          _emit(ShelvesLoaded(shelves, bookLists: currentBookLists.cast()));
        } else {
          _emit(ShelvesError(failure.message));
        }
      }
    } else {
      final shelves = (shelvesResult as Right).value as List<Shelf>;

      final bookLists = bookListsResult.isRight()
          ? (bookListsResult as Right).value as List
          : <dynamic>[];

      _emit(ShelvesLoaded(
        shelves,
        bookLists: bookLists.cast(),
      ));

      // Restore persisted list selection if book lists were loaded
      if (bookLists.isNotEmpty) {
        _restorePersistedListSelection();
      }
    }
  }

  /// Load shelves progressively - emit state after each shelf loads
  Future<void> _loadShelvesProgressively(bool shouldFetchLists) async {
    // Double-check auth state before progressive loading
    final authState = authNotifier.state;
    if (authState is Unauthenticated) {
      return;
    }

    try {
      // Get shelf keys
      final keysResult = await repository.getConfiguredShelfKeys();
      if (keysResult.isLeft()) {
        final failure = (keysResult as Left).value as Failure;
        _emit(ShelvesError(failure.message));
        return;
      }

      final shelfKeys = (keysResult as Right).value as List<String>;
      final loadedShelves = <Shelf>[];

      // Fetch book lists in parallel while loading first shelf
      final bookListsFuture = shouldFetchLists
          ? getBookListsUseCase()
          : Future.value(Right(<dynamic>[]));

      // Load each shelf and emit state progressively
      for (final shelfKey in shelfKeys) {
        try {
          final shelfResult = await repository.getShelf(
            shelfKey: shelfKey,
            forceRefresh: true,
          );

          if (shelfResult.isRight()) {
            final shelf = (shelfResult as Right).value as Shelf;
            loadedShelves.add(shelf);

            // Emit state with shelves loaded so far
            // Book lists will be empty until they finish loading
            _emit(ShelvesLoaded(
              List.from(loadedShelves),
              bookLists: [],
              isRefreshing: true,
            ));
          }
        } catch (e) {
          // Continue with other shelves
          continue;
        }
      }

      // Wait for book lists to finish
      final bookListsResult = await bookListsFuture as Either<Failure, List>;
      final bookLists = bookListsResult.isRight()
          ? (bookListsResult as Right).value as List
          : <dynamic>[];

      // Emit final state with all data and refreshing=false
      if (loadedShelves.isNotEmpty) {
        _emit(ShelvesLoaded(
          loadedShelves,
          bookLists: bookLists.cast(),
          isRefreshing: false,
        ));

        // Restore persisted list selection if book lists were loaded
        if (bookLists.isNotEmpty) {
          _restorePersistedListSelection();
        }
      } else {
        _emit(const ShelvesError('Failed to load any shelves'));
      }
    } on AuthException {
      if (_state is! ShelvesLoaded) {
        _emit(const ShelvesInitial());
      }
    } catch (e) {
      _emit(ShelvesError('Failed to load shelves: $e'));
    }
  }

  /// Refresh shelves from server
  Future<void> refreshShelves() async {
    _checkNotDisposed();
    
    // Show refreshing indicator if already loaded
    if (_state is ShelvesLoaded) {
      final currentState = _state as ShelvesLoaded;
      _emit(ShelvesLoaded(
        currentState.shelves,
        bookLists: currentState.bookLists,
        isRefreshing: true,
      ));
    }

    // Fetch shelves, book lists, and loans concurrently
    final results = await Future.wait([
      refreshShelvesUseCase(),
      getBookListsUseCase(),
      repository.getUserLoans(forceRefresh: true),
    ]);

    final shelvesResult = results[0];
    final bookListsResult = results[1];
    final loansResult = results[2];

    // Update loans data if successful
    if (loansResult.isRight()) {
      _userLoans = (loansResult as Right).value as Map<String, dynamic>;
    }

    // Handle results
    if (shelvesResult.isLeft()) {
      final failure = (shelvesResult as Left).value as Failure;

      // If it's an auth failure, don't show error - router will redirect to login
      if (failure is AuthFailure || failure is UnauthorizedFailure) {
        LoggingService.error('DEBUG: refreshShelves() - auth failure detected, router will handle redirect');
        // Keep current state and clear refreshing flag
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          _emit(ShelvesLoaded(
            currentState.shelves,
            bookLists: currentState.bookLists,
            isRefreshing: false,
          ));
        }
        return;
      }

      // If we had cached data, keep it and just clear refreshing flag
      // This prevents losing partially loaded data if user navigates away
      if (_state is ShelvesLoaded) {
        final currentState = _state as ShelvesLoaded;
        _emit(ShelvesLoaded(
          currentState.shelves,
          bookLists: currentState.bookLists,
          isRefreshing: false,
        ));
      } else {
        _emit(ShelvesError(failure.message));
      }
    } else {
      final shelves = (shelvesResult as Right).value as List<Shelf>;

      final bookLists = bookListsResult.isRight()
          ? (bookListsResult as Right).value as List
          : <dynamic>[];

      _emit(ShelvesLoaded(
        shelves,
        bookLists: bookLists.cast(),
      ));
    }
  }

  /// Refresh a single shelf from server
  Future<void> refreshShelf(String shelfKey) async {
    _checkNotDisposed();
    
    if (_state is! ShelvesLoaded) return;

    // Prevent concurrent refreshes of the same shelf
    if (_refreshingShelves.contains(shelfKey)) {
      // Add to queue if not already there
      if (!_refreshQueue.contains(shelfKey)) {
        _refreshQueue.add(shelfKey);
        _processRefreshQueue();
      }
      return;
    }

    // Mark shelf as refreshing
    _refreshingShelves.add(shelfKey);

    final currentState = _state as ShelvesLoaded;

    // Mark as refreshing
    _emit(ShelvesLoaded(
      currentState.shelves,
      bookLists: currentState.bookLists,
      isRefreshing: true,
    ));

    try {
      // Fetch shelf and loans concurrently
      final results = await Future.wait([
        repository.getShelf(shelfKey: shelfKey, forceRefresh: true),
        repository.getUserLoans(forceRefresh: true),
      ]);

      final result = results[0];
      final loansResult = results[1];

      // Update loans data if successful
      if (loansResult.isRight()) {
        _userLoans = (loansResult as Right).value as Map<String, dynamic>;
      }

      result.fold(
        (failure) {
          // On error, keep current data and clear refreshing flag
          _emit(ShelvesLoaded(
            currentState.shelves,
            bookLists: currentState.bookLists,
            isRefreshing: false,
          ));
        },
        (updatedShelf) {
          // Update just this shelf in the list
          final updatedShelves = currentState.shelves.map<Shelf>((shelf) {
            return shelf.key == shelfKey ? updatedShelf as Shelf : shelf;
          }).toList();

          _emit(ShelvesLoaded(
            updatedShelves,
            bookLists: currentState.bookLists,
            isRefreshing: false,
          ));

          // Process any redirect candidates in the background
          _processRedirectCandidates();
        },
      );
    } finally {
      // Always remove from refreshing set when done
      _refreshingShelves.remove(shelfKey);
      
      // Process any queued refreshes for this shelf
      _processRefreshQueue();
    }
  }

  /// Process the refresh queue with debouncing
  void _processRefreshQueue() {
    // Cancel any existing timer
    _refreshQueueTimer?.cancel();

    // If queue is empty, nothing to do
    if (_refreshQueue.isEmpty) return;

    // Process queue after a short delay to allow rapid additions to be batched
    _refreshQueueTimer = Timer(const Duration(milliseconds: 200), () {
      // Get the first item in queue
      if (_refreshQueue.isNotEmpty) {
        final shelfKey = _refreshQueue.removeAt(0);
        
        // Only process if not already refreshing
        if (!_refreshingShelves.contains(shelfKey)) {
          refreshShelf(shelfKey);
        }
        
        // Process remaining items
        _processRefreshQueue();
      }
    });
  }

  /// Check if a shelf needs refresh and refresh it if stale
  Future<void> refreshShelfIfStale(String shelfKey) async {
    if (_state is! ShelvesLoaded) return;

    final currentState = _state as ShelvesLoaded;
    final shelf = currentState.shelves.firstWhere(
      (s) => s.key == shelfKey,
      orElse: () => throw Exception('Shelf not found: $shelfKey'),
    );

    // Only refresh if stale
    if (shelf.isStale) {
      await refreshShelf(shelfKey);
    }
  }

  /// Move book to a different shelf
  Future<bool> moveBookToShelf({
    required Book book,
    required String targetShelfKey,
  }) async {
    final result = await moveBookToShelfUseCase(
      book: book,
      targetShelfKey: targetShelfKey,
    );

    return result.fold(
      (failure) {
        // Show error but keep current state
        _emit(ShelvesError(failure.message));
        return false;
      },
      (_) {
        // Update shelves in memory instead of full reload
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          final updatedShelves = currentState.shelves.map((shelf) {
            if (shelf.key == targetShelfKey) {
              // Find and update the book on the target shelf
              final existingBookIndex = shelf.books.indexWhere(
                (b) => b.workId == book.workId,
              );

              if (existingBookIndex != -1) {
                // Replace existing book (edition change on same shelf)
                final updatedBooks = List<Book>.from(shelf.books);
                updatedBooks[existingBookIndex] = book;
                final updatedShelf = shelf.copyWith(books: updatedBooks);
                // Return shelf with books sorted according to shelf's sort configuration
                return updatedShelf.copyWith(books: updatedShelf.sortedBooks);
              } else {
                // Add new book to target shelf
                final updatedShelf = shelf.copyWith(
                  books: [...shelf.books, book],
                  totalCount: shelf.totalCount + 1,
                );
                // Return shelf with books sorted according to shelf's sort configuration
                return updatedShelf.copyWith(books: updatedShelf.sortedBooks);
              }
            } else {
              // Remove book from other shelves
              final updatedBooks = shelf.books
                  .where((b) => b.workId != book.workId)
                  .toList();
              final removedCount = shelf.books.length - updatedBooks.length;
              return shelf.copyWith(
                books: updatedBooks,
                totalCount: shelf.totalCount - removedCount,
              );
            }
          }).toList();
          _emit(currentState.copyWith(shelves: updatedShelves));
        }
        return true;
      },
    );
  }

  /// Remove book from shelf
  Future<bool> removeBookFromShelf({
    required Book book,
    required String shelfKey,
  }) async {
    final result = await repository.removeBookFromShelf(
      book: book,
      shelfKey: shelfKey,
    );

    return result.fold(
      (failure) {
        _emit(ShelvesError(failure.message));
        return false;
      },
      (_) {
        // Update shelf in memory instead of full reload
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          final updatedShelves = currentState.shelves.map((shelf) {
            if (shelf.key == shelfKey) {
              // Remove book from this shelf
              final updatedBooks = shelf.books
                  .where((b) => b.workId != book.workId)
                  .toList();
              final removedCount = shelf.books.length - updatedBooks.length;
              return shelf.copyWith(
                books: updatedBooks,
                totalCount: shelf.totalCount - removedCount,
              );
            }
            return shelf;
          }).toList();
          _emit(currentState.copyWith(shelves: updatedShelves));
        }
        return true;
      },
    );
  }

  /// Update shelf sort order
  Future<void> updateSort(
    String shelfKey,
    ShelfSortOrder sortOrder,
    bool ascending,
  ) async {
    final result = await updateShelfSortUseCase(
      shelfKey: shelfKey,
      sortOrder: sortOrder,
      ascending: ascending,
    );

    result.fold(
      (failure) => _emit(ShelvesError(failure.message)),
      (updatedShelf) {
        // Update the shelf in current state
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          final updatedShelves = currentState.shelves.map((shelf) {
            return shelf.key == shelfKey ? updatedShelf : shelf;
          }).toList();
          _emit(currentState.copyWith(shelves: updatedShelves));
        }
      },
    );
  }

  /// Refresh a single book's edition data from the server
  Future<void> refreshBook({
    required Book book,
    required String shelfKey,
  }) async {
    if (_state is! ShelvesLoaded) return;

    try {
      // Fetch fresh edition details from the API
      final editionDetails = await bookDetailsDataSource.fetchBookDetails(
        editionId: book.editionId,
      );

      // Create updated book with fresh data from edition details
      final updatedBook = Book(
        editionId: book.editionId,
        workId: book.workId,
        title: editionDetails.title,
        authors: editionDetails.authors.isNotEmpty ? editionDetails.authors : book.authors,
        coverImageId: editionDetails.coverImageId,
        coverEditionId: book.editionId, // Use edition ID for cover
        publishDate: editionDetails.publishDate ?? book.publishDate,
        publisher: editionDetails.publisher ?? book.publisher,
        numberOfPages: editionDetails.numberOfPages ?? book.numberOfPages,
        isbn: [...editionDetails.isbn10, ...editionDetails.isbn13],
        description: editionDetails.description ?? book.description,
        iaId: editionDetails.ocaid ?? book.iaId,
        addedDate: book.addedDate,
        lastModified: DateTime.now(),
      );

      // Update the book in the shelf state
      final currentState = _state as ShelvesLoaded;
      final updatedShelves = currentState.shelves.map((shelf) {
        if (shelf.key == shelfKey) {
          // Find and update the book on this shelf
          final updatedBooks = shelf.books.map((b) {
            return b.workId == book.workId ? updatedBook : b;
          }).toList();
          return shelf.copyWith(books: updatedBooks);
        }
        return shelf;
      }).toList();

      _emit(currentState.copyWith(shelves: updatedShelves));
    } catch (e) {
      // On error, just re-emit current state to trigger a rebuild
      final currentState = _state as ShelvesLoaded;
      _emit(currentState.copyWith());
    }
  }

  /// Update shelf visibility
  Future<void> updateShelfVisibility({
    required String shelfKey,
    required bool isVisible,
  }) async {
    final result = await repository.updateShelfVisibility(
      shelfKey: shelfKey,
      isVisible: isVisible,
    );

    result.fold(
      (failure) => _emit(ShelvesError(failure.message)),
      (updatedShelf) {
        // Update the shelf in current state
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          final updatedShelves = currentState.shelves.map((shelf) {
            return shelf.key == shelfKey ? updatedShelf : shelf;
          }).toList();
          _emit(currentState.copyWith(shelves: updatedShelves));
        }
      },
    );
  }

  /// Refresh user loans from server
  Future<void> refreshUserLoans() async {
    // Don't refresh if user is not authenticated
    final authState = authNotifier.state;
    if (authState is Unauthenticated) {
      return;
    }

    final result = await repository.getUserLoans(forceRefresh: true);
    result.fold(
      (failure) {
        // Don't emit error state for loans - just keep existing loans
      },
      (loans) {
        _userLoans = loans;
        // Trigger a rebuild to update loan badges
        if (_state is ShelvesLoaded) {
          final currentState = _state as ShelvesLoaded;
          _emit(currentState.copyWith());
        }
      },
    );
  }

  /// Get loan data for a specific edition ID
  Map<String, dynamic>? getLoanForEdition(String editionId) {
    return _userLoans[editionId];
  }

  /// Get remaining loan minutes for a book edition
  int getLoanMinutesRemaining(String editionId) {
    final loanData = _userLoans[editionId];
    if (loanData == null) return 0;

    try {
      // Parse expiry date (format: "2025-12-21 01:16:44")
      final expiryString = loanData['expiry'] as String;
      // Add 'Z' to treat as UTC
      final expiry = DateTime.parse('${expiryString}Z');
      final remaining = expiry.difference(DateTime.now());
      return remaining.inMinutes;
    } catch (e) {
      LoggingService.error('Error parsing loan expiry: $e');
      return 0;
    }
  }

  /// Initialize - load shelves and loans on app start
  Future<void> initialize() async {
    await Future.wait([
      loadShelves(),
      refreshUserLoans(),
    ]);

    // Process any redirect candidates in the background
    _processRedirectCandidates();

    // Cleanup orphaned visual adjustments in the background
    _cleanupOrphanedVisualAdjustments();
  }

  /// Cleanup visual adjustments for books no longer in any shelf
  Future<void> _cleanupOrphanedVisualAdjustments() async {
    if (_state is! ShelvesLoaded) return;

    final currentState = _state as ShelvesLoaded;

    // Collect all book IDs from all shelves
    final validBookIds = <String>{};
    for (final shelf in currentState.shelves) {
      for (final book in shelf.books) {
        // Add all possible book identifiers that might be used
        if (book.editionId.isNotEmpty) {
          validBookIds.add(book.editionId);
        }
        if (book.workId.isNotEmpty) {
          validBookIds.add(book.workId);
        }
      }
    }

    if (validBookIds.isEmpty) return;

    try {
      final removedCount = await visualAdjustmentsService.cleanupOrphanedAdjustments(validBookIds);
      if (removedCount > 0) {
        LoggingService.debug('Cleaned up $removedCount orphaned visual adjustment(s)');
      }
    } catch (e) {
      LoggingService.warning('Error cleaning up visual adjustments: $e');
    }
  }

  /// Process books that may be redirected works (background task)
  Future<void> _processRedirectCandidates() async {
    if (_state is! ShelvesLoaded) return;

    LoggingService.error('DEBUG: _processRedirectCandidates() - Starting background redirect check');
    final currentState = _state as ShelvesLoaded;
    bool hasChanges = false;
    final updatedShelves = List<Shelf>.from(currentState.shelves);
    int candidateCount = 0;
    int totalBooks = 0;

    for (int shelfIndex = 0; shelfIndex < updatedShelves.length; shelfIndex++) {
      final shelf = updatedShelves[shelfIndex];
      LoggingService.error('DEBUG: Checking shelf ${shelf.key} with ${shelf.books.length} books');

      for (int bookIndex = 0; bookIndex < shelf.books.length; bookIndex++) {
        final book = shelf.books[bookIndex];
        totalBooks++;

        // Debug: Print book details for books with suspicious metadata
        if (book.title == 'Unknown Title' || book.authors.isEmpty || book.coverImageId == null) {
          LoggingService.error('DEBUG: Book ${bookIndex + 1}/${shelf.books.length}:');
          LoggingService.error('DEBUG:   workId: "${book.workId}" (isEmpty: ${book.workId.isEmpty})');
          LoggingService.error('DEBUG:   title: "${book.title}" (== "Unknown Title": ${book.title == 'Unknown Title'})');
          LoggingService.error('DEBUG:   authors: ${book.authors} (isEmpty: ${book.authors.isEmpty})');
          LoggingService.error('DEBUG:   coverImageId: ${book.coverImageId} (== null: ${book.coverImageId == null})');
        }

        // Check if this book needs redirect checking
        // We detect this by checking if it has missing metadata (title, authors, cover)
        // which indicates the work has been merged/redirected
        if (book.workId.isNotEmpty &&
            book.title == 'Unknown Title' &&
            book.authors.isEmpty &&
            book.coverImageId == null) {
          candidateCount++;
          try {
            LoggingService.error('DEBUG: ===== REDIRECT CANDIDATE #$candidateCount DETECTED =====');
            LoggingService.error('DEBUG: Work ID: ${book.workId}');
            LoggingService.error('DEBUG: Edition ID: ${book.editionId}');
            LoggingService.error('DEBUG: Shelf: ${shelf.key}');
            LoggingService.error('DEBUG: Checking redirect for work ${book.workId}');

            // Resolve the redirect
            final result = await bookDetailsDataSource.resolveWorkRedirect(
              workId: book.workId,
            );

            final redirectedWorkId = result['redirectedWorkId'] as String?;
            final workData = result['workData'] as Map<String, dynamic>?;

            if (redirectedWorkId != null && workData != null) {
              LoggingService.error('DEBUG: ===== REDIRECT RESOLUTION =====');
              LoggingService.error('DEBUG: Old work ID: ${book.workId}');
              LoggingService.error('DEBUG: New work ID: $redirectedWorkId');
              LoggingService.error('DEBUG: Edition ID: ${book.editionId}');
              LoggingService.error('DEBUG: Shelf: ${shelf.key}');

              // Extract cover from work data
              int? coverImageId;
              String? coverEditionId;
              LoggingService.error('DEBUG: Work data covers field: ${workData['covers']}');
              if (workData['covers'] != null && (workData['covers'] as List).isNotEmpty) {
                coverImageId = (workData['covers'] as List).first as int?;
                LoggingService.error('DEBUG: Extracted cover ID: $coverImageId');
                // Clear coverEditionId so the new coverImageId will be used
                coverEditionId = null;
                LoggingService.error('DEBUG: Set coverEditionId to null');
              } else {
                // Keep existing cover data if work has no covers
                coverImageId = book.coverImageId;
                coverEditionId = book.coverEditionId;
                LoggingService.error('DEBUG: No covers in work data, keeping old cover data');
              }
              LoggingService.error('DEBUG: Old book cover - imageId: ${book.coverImageId}, editionId: ${book.coverEditionId}');
              LoggingService.error('DEBUG: New book cover - imageId: $coverImageId, editionId: $coverEditionId');

              // Extract updated book data from work
              final updatedBook = Book(
                editionId: book.editionId,
                workId: redirectedWorkId,
                title: workData['title'] as String? ?? book.title,
                authors: (workData['authors'] as List?)
                        ?.map((a) => a['name'] as String? ?? '')
                        .where((name) => name.isNotEmpty)
                        .toList() ??
                    book.authors,
                coverImageId: coverImageId,
                coverEditionId: coverEditionId,
                publishDate: book.publishDate,
                publisher: book.publisher,
                numberOfPages: book.numberOfPages,
                isbn: book.isbn,
                description: book.description,
                availability: book.availability,
                iaId: book.iaId,
                addedDate: book.addedDate,
                lastModified: DateTime.now(),
              );

              LoggingService.error('DEBUG: Updated book created - title: "${updatedBook.title}"');
              LoggingService.error('DEBUG: Updated book coverImageUrl: ${updatedBook.coverImageUrl}');
              LoggingService.error('DEBUG: Updated book coverImageUrls: ${updatedBook.coverImageUrls}');

              // Update the book in the shelf locally
              final updatedBooks = List<Book>.from(shelf.books);
              updatedBooks[bookIndex] = updatedBook;
              updatedShelves[shelfIndex] = shelf.copyWith(books: updatedBooks);
              hasChanges = true;

              // Update on server: two-step process
              // Step 1: Remove old work from shelf
              // Step 2: Add new work to shelf
              _updateRedirectedBookOnServer(
                oldBook: book,
                newBook: updatedBook,
                shelfKey: shelf.key,
              );
            }
          } catch (e) {
            LoggingService.error('DEBUG: Error processing redirect for ${book.workId}: $e');
            // Continue with other books even if one fails
          }
        }
      }
    }

    // If we made any changes, emit the updated state
    if (hasChanges) {
      LoggingService.error('DEBUG: _processRedirectCandidates() - hasChanges=true, preparing to emit');

      // Ensure we're on a fresh microtask and state is still loaded
      await Future.delayed(Duration.zero);

      if (_state is ShelvesLoaded) {
        LoggingService.error('DEBUG: _processRedirectCandidates() - Emitting updated state with ${updatedShelves.length} shelves');
        final latestState = _state as ShelvesLoaded;
        _emit(latestState.copyWith(shelves: updatedShelves));
        LoggingService.error('DEBUG: _processRedirectCandidates() - State emitted, notifyListeners() called');
      } else {
        LoggingService.error('DEBUG: _processRedirectCandidates() - State is no longer ShelvesLoaded, skipping emit');
      }
    } else {
      LoggingService.error('DEBUG: _processRedirectCandidates() - NOT emitting: hasChanges=false');
    }

    LoggingService.error('DEBUG: _processRedirectCandidates() - Complete. Checked $totalBooks books across ${updatedShelves.length} shelves, found $candidateCount candidates, updated ${hasChanges ? "some" : "none"}');
  }

  /// Update a redirected book on the server (two-step process)
  /// Calls remote data source directly to avoid triggering state changes
  Future<void> _updateRedirectedBookOnServer({
    required Book oldBook,
    required Book newBook,
    required String shelfKey,
  }) async {
    try {
      LoggingService.error('DEBUG: Step 1 - Removing old work (${oldBook.workId}) from shelf');

      // Step 1: Remove old work from shelf
      // Call remote data source directly to avoid state change race condition
      await shelfRemoteDataSource.moveBookToShelf(
        workId: oldBook.workId,
        editionId: oldBook.editionId.isNotEmpty ? oldBook.editionId : null,
        targetShelfKey: '-1', // Remove from all shelves
      );

      LoggingService.error('DEBUG: Step 1 SUCCESS - Old work removed');
      LoggingService.error('DEBUG: Step 2 - Adding new work (${newBook.workId}) to shelf $shelfKey');

      // Step 2: Add new work to shelf
      // Call remote data source directly to avoid state change race condition
      await shelfRemoteDataSource.moveBookToShelf(
        workId: newBook.workId,
        editionId: newBook.editionId.isNotEmpty ? newBook.editionId : null,
        targetShelfKey: shelfKey,
      );

      LoggingService.error('DEBUG: Step 2 SUCCESS - New work added');
      LoggingService.error('DEBUG: ===== Redirect resolution complete: ${oldBook.workId} → ${newBook.workId} =====');
    } catch (e, stackTrace) {
      LoggingService.error('DEBUG: ===== ERROR in _updateRedirectedBookOnServer =====');
      LoggingService.error('DEBUG: Exception: $e');
      LoggingService.error('DEBUG: Stack trace: $stackTrace');
      LoggingService.error('DEBUG: Old work: ${oldBook.workId}, New work: ${newBook.workId}');
      LoggingService.error('DEBUG: This may leave the book in an inconsistent state on the server');
      LoggingService.error('DEBUG: ===== END ERROR =====');
    }
  }

  /// Select a list and load its contents
  ///
  /// Fetches the list seeds and converts them to books for display
  Future<void> selectList(String listUrl, {bool forceRefresh = false}) async {
    final currentState = _state;
    if (currentState is! ShelvesLoaded) return;

    // Set loading state
    _emit(currentState.copyWith(
      isLoadingListContents: true,
      selectedListUrl: listUrl,
      listBooks: [], // Clear previous books
    ));

    // Fetch list seeds
    final result = await getListSeedsUseCase(
      listUrl: listUrl,
      forceRefresh: forceRefresh,
    );

    result.fold(
      (failure) {
        // On error, keep list selected but show empty books
        if (_state is ShelvesLoaded) {
          _emit((_state as ShelvesLoaded).copyWith(
            isLoadingListContents: false,
            listBooks: [],
          ));
        }
        LoggingService.warning('Error loading list seeds: ${failure.message}');
      },
      (books) {
        // Update state with loaded books
        if (_state is ShelvesLoaded) {
          _emit((_state as ShelvesLoaded).copyWith(
            isLoadingListContents: false,
            listBooks: books,
          ));

          // Persist selection
          _persistListSelection(listUrl);
        }
      },
    );
  }

  /// Clear list selection
  void clearListSelection() {
    final currentState = _state;
    if (currentState is! ShelvesLoaded) return;

    _emit(currentState.copyWith(
      clearSelectedList: true,
      listBooks: [],
      isLoadingListContents: false,
    ));

    // Clear persisted selection
    _persistListSelection(null);
  }

  /// Refresh the currently selected list
  Future<void> refreshCurrentList() async {
    final currentState = _state;
    if (currentState is! ShelvesLoaded) return;

    final selectedUrl = currentState.selectedListUrl;
    if (selectedUrl == null) return;

    // Re-select the list with forceRefresh
    await selectList(selectedUrl, forceRefresh: true);
  }

  /// Persist list selection to preferences
  Future<void> _persistListSelection(String? listUrl) async {
    try {
      // Access local data source through repository
      // The repository has access to the local data source
      if (repository is ShelfRepositoryImpl) {
        await (repository as dynamic).localDataSource.updateSelectedListUrl(listUrl);
      }
    } catch (e) {
      LoggingService.warning('Error persisting list selection: $e');
    }
  }

  /// Load persisted list selection
  Future<String?> _loadPersistedListSelection() async {
    try {
      // Access local data source through repository
      if (repository is ShelfRepositoryImpl) {
        return await (repository as dynamic).localDataSource.getSelectedListUrl();
      }
      return null;
    } catch (e) {
      LoggingService.warning('Error loading persisted list selection: $e');
      return null;
    }
  }

  /// Restore persisted list selection after loading book lists
  Future<void> _restorePersistedListSelection() async {
    // Only restore if we're in a loaded state with no current selection
    final currentState = _state;
    if (currentState is! ShelvesLoaded) return;
    if (currentState.selectedListUrl != null) return; // Already have a selection

    // Load persisted selection
    final persistedUrl = await _loadPersistedListSelection();
    if (persistedUrl == null) return;

    // Verify the persisted URL matches one of the loaded book lists
    final matchingList = currentState.bookLists.any((list) => list.url == persistedUrl);
    if (!matchingList) {
      // Persisted list no longer exists, clear the preference
      await _persistListSelection(null);
      return;
    }

    // Restore the selection
    await selectList(persistedUrl);
  }

  /// Add a book to a list
  Future<void> addBookToList({
    required Book book,
    required String listUrl,
  }) async {
    try {
      await shelfRemoteDataSource.addBookToList(
        listUrl: listUrl,
        workId: book.workId,
        editionId: book.editionId,
      );

      final currentState = _state;
      if (currentState is! ShelvesLoaded) return;

      // Refresh book lists to get updated seed counts
      final bookListsResult = await getBookListsUseCase();
      final updatedBookLists = bookListsResult.fold(
        (failure) => currentState.bookLists, // Keep current lists on error
        (lists) => lists,
      );

      // Update state with new book lists
      _emit(currentState.copyWith(bookLists: updatedBookLists));

      // If the book was added to the currently selected list, refresh its contents
      if (currentState.selectedListUrl == listUrl) {
        await selectList(listUrl, forceRefresh: true);
      }
    } catch (e) {
      LoggingService.warning('Error adding book to list: $e');
      rethrow;
    }
  }

  /// Remove a book from the currently selected list
  Future<void> removeBookFromCurrentList({
    required Book book,
  }) async {
    final currentState = _state;
    if (currentState is! ShelvesLoaded || currentState.selectedListUrl == null) {
      LoggingService.warning('Cannot remove book: no list selected');
      return;
    }

    try {
      await shelfRemoteDataSource.removeBookFromList(
        listUrl: currentState.selectedListUrl!,
        workId: book.workId,
        editionId: book.editionId,
      );

      // Refresh book lists to get updated seed counts
      final bookListsResult = await getBookListsUseCase();
      final updatedBookLists = bookListsResult.fold(
        (failure) => currentState.bookLists, // Keep current lists on error
        (lists) => lists,
      );

      // Update state with new book lists
      _emit(currentState.copyWith(bookLists: updatedBookLists));

      // Refresh the current list to show the book has been removed
      await selectList(currentState.selectedListUrl!, forceRefresh: true);
    } catch (e) {
      LoggingService.warning('Error removing book from list: $e');
      rethrow;
    }
  }
}
