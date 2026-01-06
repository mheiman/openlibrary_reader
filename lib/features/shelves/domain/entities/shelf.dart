import 'package:equatable/equatable.dart';

import 'book.dart';

/// Sort order options for shelves
enum ShelfSortOrder {
  title,
  author,
  dateAdded,
  datePublished,
}

/// Shelf entity representing a collection of books
class Shelf extends Equatable {
  final String key; // Unique key (e.g., 'currently-reading', 'want-to-read')
  final String name; // Display name (e.g., 'Reading', 'To Read')
  final String olName; // OpenLibrary API name (e.g., 'Currently Reading')
  final int olId; // OpenLibrary shelf ID (1=want, 2=reading, 3=already-read)
  final List<Book> books;
  final int totalCount; // Total number of books (from API, may be > books.length due to pagination)
  final ShelfSortOrder sortOrder;
  final bool sortAscending; // true = ascending, false = descending
  final bool isVisible;
  final int displayOrder; // Order to display shelf in UI
  final DateTime? lastSynced;

  const Shelf({
    required this.key,
    required this.name,
    required this.olName,
    required this.olId,
    this.books = const [],
    int? totalCount,
    this.sortOrder = ShelfSortOrder.dateAdded,
    this.sortAscending = true,
    this.isVisible = true,
    this.displayOrder = 0,
    this.lastSynced,
  }) : totalCount = totalCount ?? books.length;

  @override
  List<Object?> get props => [
        key,
        name,
        olName,
        olId,
        books,
        totalCount,
        sortOrder,
        sortAscending,
        isVisible,
        displayOrder,
        lastSynced,
      ];

  /// Get number of books in shelf (total from API, not just loaded)
  int get bookCount => totalCount;

  /// Check if shelf needs refresh (stale after 6 hours)
  bool get isStale {
    if (lastSynced == null) return true;
    final now = DateTime.now();
    final difference = now.difference(lastSynced!);
    return difference.inHours >= 6;
  }

  /// Get sorted books based on current sort order and direction
  List<Book> get sortedBooks {
    final booksCopy = List<Book>.from(books);

    int Function(Book, Book) comparator;
    switch (sortOrder) {
      case ShelfSortOrder.title:
        comparator = (a, b) {
          final titleA = _getSortableTitle(a.title);
          final titleB = _getSortableTitle(b.title);
          return titleA.compareTo(titleB);
        };
        break;
      case ShelfSortOrder.author:
        comparator = (a, b) {
          final authorA = a.authors.isNotEmpty ? a.authors.first.toLowerCase() : '';
          final authorB = b.authors.isNotEmpty ? b.authors.first.toLowerCase() : '';
          return authorA.compareTo(authorB);
        };
        break;
      case ShelfSortOrder.dateAdded:
        comparator = (a, b) {
          // Nulls sort to the end
          if (a.addedDate == null && b.addedDate == null) return 0;
          if (a.addedDate == null) return 1;
          if (b.addedDate == null) return -1;
          return a.addedDate!.compareTo(b.addedDate!);
        };
        break;
      case ShelfSortOrder.datePublished:
        comparator = (a, b) {
          // Nulls sort to the end
          if (a.publishDate == null && b.publishDate == null) return 0;
          if (a.publishDate == null) return 1;
          if (b.publishDate == null) return -1;

          // Try to parse as integers (for years like "2020", "2019")
          final aYear = int.tryParse(a.publishDate!);
          final bYear = int.tryParse(b.publishDate!);

          if (aYear != null && bYear != null) {
            return aYear.compareTo(bYear);
          }

          // Fallback to string comparison
          return a.publishDate!.compareTo(b.publishDate!);
        };
        break;
    }

    // Apply direction
    if (sortAscending) {
      booksCopy.sort(comparator);
    } else {
      booksCopy.sort((a, b) => comparator(b, a));
    }

    return booksCopy;
  }

  /// Get sortable version of title with leading articles moved to end
  /// "The Great Gatsby" -> "great gatsby, the"
  /// "A Tale of Two Cities" -> "tale of two cities, a"
  /// "An American Tragedy" -> "american tragedy, an"
  String _getSortableTitle(String title) {
    final lowerTitle = title.toLowerCase().trim();

    // Check for leading articles
    if (lowerTitle.startsWith('the ')) {
      return '${lowerTitle.substring(4)}, the';
    } else if (lowerTitle.startsWith('a ')) {
      return '${lowerTitle.substring(2)}, a';
    } else if (lowerTitle.startsWith('an ')) {
      return '${lowerTitle.substring(3)}, an';
    }

    return lowerTitle;
  }

  /// Create a copy with updated fields
  Shelf copyWith({
    String? key,
    String? name,
    String? olName,
    int? olId,
    List<Book>? books,
    int? totalCount,
    ShelfSortOrder? sortOrder,
    bool? sortAscending,
    bool? isVisible,
    int? displayOrder,
    DateTime? lastSynced,
  }) {
    return Shelf(
      key: key ?? this.key,
      name: name ?? this.name,
      olName: olName ?? this.olName,
      olId: olId ?? this.olId,
      books: books ?? this.books,
      totalCount: totalCount ?? this.totalCount,
      sortOrder: sortOrder ?? this.sortOrder,
      sortAscending: sortAscending ?? this.sortAscending,
      isVisible: isVisible ?? this.isVisible,
      displayOrder: displayOrder ?? this.displayOrder,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}

/// Default shelf configurations
class DefaultShelves {
  static const currentlyReading = ShelfConfig(
    key: 'currently-reading',
    name: 'Reading',
    olName: 'Currently Reading',
    olId: 2,
    displayOrder: 1,
  );

  static const wantToRead = ShelfConfig(
    key: 'want-to-read',
    name: 'To Read',
    olName: 'Want to Read',
    olId: 1,
    displayOrder: 0,
  );

  static const alreadyRead = ShelfConfig(
    key: 'already-read',
    name: 'Have Read',
    olName: 'Already Read',
    olId: 3,
    displayOrder: 2,
  );

  /// Get all default shelf configurations
  static List<ShelfConfig> get all => [
        wantToRead,
        currentlyReading,
        alreadyRead,
      ];

  /// Get shelf configuration by key
  static ShelfConfig? getByKey(String key) {
    return all.firstWhere(
      (config) => config.key == key,
      orElse: () => wantToRead,
    );
  }
}

/// Shelf configuration for creating new shelves
class ShelfConfig {
  final String key;
  final String name;
  final String olName;
  final int olId;
  final int displayOrder;

  const ShelfConfig({
    required this.key,
    required this.name,
    required this.olName,
    required this.olId,
    required this.displayOrder,
  });

  /// Convert to Shelf entity
  Shelf toShelf({
    List<Book> books = const [],
    ShelfSortOrder sortOrder = ShelfSortOrder.dateAdded,
    bool isVisible = true,
  }) {
    return Shelf(
      key: key,
      name: name,
      olName: olName,
      olId: olId,
      books: books,
      sortOrder: sortOrder,
      isVisible: isVisible,
      displayOrder: displayOrder,
    );
  }
}
