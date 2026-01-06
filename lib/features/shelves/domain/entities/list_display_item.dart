import 'author.dart';
import 'book.dart';

/// Sealed class for items that can appear in list grids
/// Provides type-safe polymorphism for books, authors, and subjects
sealed class ListDisplayItem {
  /// Unique identifier for this item
  String get id;

  /// Primary display text (title for books, name for authors)
  String get primaryText;

  /// Secondary display text (author for books, "Author" for authors)
  String get secondaryText;

  /// Cover image ID for the covers API, or null for default icon
  int? get coverImageId;

  const ListDisplayItem();
}

/// Book item wrapper for display in lists
class BookDisplayItem extends ListDisplayItem {
  final Book book;

  const BookDisplayItem(this.book);

  @override
  String get id => book.workId;

  @override
  String get primaryText => book.title;

  @override
  String get secondaryText => book.authors.isEmpty ? '' : book.authors.join(', ');

  @override
  int? get coverImageId => book.coverImageId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookDisplayItem &&
          runtimeType == other.runtimeType &&
          book == other.book;

  @override
  int get hashCode => book.hashCode;
}

/// Author item for display in lists
class AuthorDisplayItem extends ListDisplayItem {
  final Author author;

  const AuthorDisplayItem(this.author);

  @override
  String get id => author.id;

  @override
  String get primaryText => author.name;

  @override
  String get secondaryText => 'Author';

  @override
  int? get coverImageId => author.photoId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorDisplayItem &&
          runtimeType == other.runtimeType &&
          author == other.author;

  @override
  int get hashCode => author.hashCode;
}
