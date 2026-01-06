import 'package:equatable/equatable.dart';

/// Book edition
class Edition extends Equatable {
  final String editionId; // OLID
  final String title;
  final String? publishDate;
  final String? publisher;
  final int? numberOfPages;
  final List<String> isbn;
  final int? coverImageId;
  final String? coverEditionKey; // OLID from cover_edition_key field
  final String? format;
  final String? availability;

  const Edition({
    required this.editionId,
    required this.title,
    this.publishDate,
    this.publisher,
    this.numberOfPages,
    this.isbn = const [],
    this.coverImageId,
    this.coverEditionKey,
    this.format,
    this.availability,
  });

  @override
  List<Object?> get props => [
        editionId,
        title,
        publishDate,
        publisher,
        numberOfPages,
        isbn,
        coverImageId,
        coverEditionKey,
        format,
        availability,
      ];

  /// Get cover image URL, preferring edition cover over generic cover
  String get coverImageUrl {
    // 1. First try using the edition OLID (for edition-specific covers)
    if (editionId.isNotEmpty) {
      return 'https://covers.openlibrary.org/b/olid/$editionId-M.jpg';
    }

    // 2. Try using cover_edition_key OLID
    if (coverEditionKey != null && coverEditionKey!.isNotEmpty) {
      return 'https://covers.openlibrary.org/b/olid/$coverEditionKey-M.jpg';
    }

    // 3. Fall back to cover ID (usually work cover)
    if (coverImageId != null) {
      return 'https://covers.openlibrary.org/b/id/$coverImageId-M.jpg';
    }

    // 4. Final fallback: default avatar image
    return 'https://openlibrary.org/images/icons/avatar_book.png';
  }

  /// Get display info for edition picker
  String get displayInfo {
    final parts = <String>[];
    if (publishDate != null) parts.add(publishDate!);
    if (publisher != null) parts.add(publisher!);
    if (numberOfPages != null) parts.add('$numberOfPages pages');
    return parts.join(' • ');
  }

  /// Check if this edition can be borrowed or is open access
  bool get canBorrow {
    return availability == 'borrow_available' ||
           availability == 'borrow' ||
           availability == 'full' ||
           availability == 'open';
  }
}
