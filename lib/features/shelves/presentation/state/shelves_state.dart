import 'package:equatable/equatable.dart';

import '../../domain/entities/book_list.dart';
import '../../domain/entities/list_display_item.dart';
import '../../domain/entities/shelf.dart';

/// Shelves state
abstract class ShelvesState extends Equatable {
  const ShelvesState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ShelvesInitial extends ShelvesState {
  const ShelvesInitial();
}

/// Loading state
class ShelvesLoading extends ShelvesState {
  const ShelvesLoading();
}

/// Loaded state with shelves data
class ShelvesLoaded extends ShelvesState {
  final List<Shelf> shelves;
  final List<BookList> bookLists;
  final bool isRefreshing;
  final String? selectedListUrl; // Currently selected list URL
  final List<ListDisplayItem> listBooks; // Items (books, authors, etc.) from the selected list
  final bool isLoadingListContents; // Loading state for list contents

  const ShelvesLoaded(
    this.shelves, {
    this.bookLists = const [],
    this.isRefreshing = false,
    this.selectedListUrl,
    this.listBooks = const [],
    this.isLoadingListContents = false,
  });

  @override
  List<Object?> get props => [
        shelves,
        bookLists,
        isRefreshing,
        selectedListUrl,
        listBooks,
        isLoadingListContents,
      ];

  /// Get visible shelves sorted by display order
  List<Shelf> get visibleShelves {
    return shelves
        .where((s) => s.isVisible)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Copy with method for easy state updates
  ShelvesLoaded copyWith({
    List<Shelf>? shelves,
    List<BookList>? bookLists,
    bool? isRefreshing,
    String? selectedListUrl,
    List<ListDisplayItem>? listBooks,
    bool? isLoadingListContents,
    bool clearSelectedList = false,
  }) {
    return ShelvesLoaded(
      shelves ?? this.shelves,
      bookLists: bookLists ?? this.bookLists,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      selectedListUrl: clearSelectedList ? null : (selectedListUrl ?? this.selectedListUrl),
      listBooks: listBooks ?? this.listBooks,
      isLoadingListContents: isLoadingListContents ?? this.isLoadingListContents,
    );
  }
}

/// Error state
class ShelvesError extends ShelvesState {
  final String message;

  const ShelvesError(this.message);

  @override
  List<Object?> get props => [message];
}
