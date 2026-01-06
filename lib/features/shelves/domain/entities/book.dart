import 'package:equatable/equatable.dart';

/// Book entity (edition-level data from OpenLibrary)
class Book extends Equatable {
  final String editionId; // OLID (e.g., OL24381194M)
  final String workId; // Work ID (e.g., OL472814W)
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final int? coverImageId;
  final String? coverEditionId; // Edition ID specifically for cover lookups
  final String? publishDate;
  final String? publisher;
  final int? numberOfPages;
  final List<String> isbn;
  final String? description;
  final String? availability; // 'borrow_available', 'borrow_unavailable', etc.
  final String? iaId; // Internet Archive ID (e.g., 'harrypottersorce00rowl')
  final DateTime? addedDate;
  final DateTime? lastModified;

  const Book({
    required this.editionId,
    required this.workId,
    required this.title,
    this.authors = const [],
    this.coverUrl,
    this.coverImageId,
    this.coverEditionId,
    this.publishDate,
    this.publisher,
    this.numberOfPages,
    this.isbn = const [],
    this.description,
    this.availability,
    this.iaId,
    this.addedDate,
    this.lastModified,
  });

  @override
  List<Object?> get props => [
        editionId,
        workId,
        title,
        authors,
        coverUrl,
        coverImageId,
        coverEditionId,
        publishDate,
        publisher,
        numberOfPages,
        isbn,
        description,
        availability,
        iaId,
        addedDate,
        lastModified,
      ];

  /// Get cover image URL, preferring edition cover over work cover
  String? get coverImageUrl {
    // First try using cover edition ID (edition specifically with the cover)
    if (coverEditionId != null && coverEditionId!.isNotEmpty) {
      return 'https://covers.openlibrary.org/b/olid/$coverEditionId-M.jpg';
    }
    // Fall back to cover ID (usually work cover)
    if (coverImageId != null) {
      return 'https://covers.openlibrary.org/b/id/$coverImageId-M.jpg';
    }
    // Final fallback to explicitly provided coverUrl
    return coverUrl;
  }

  /// Get list of cover URLs to try in priority order (for fallback handling)
  List<String> get coverImageUrls {
    final urls = <String>[];

    // First try cover edition ID (user's logged edition or marked cover edition)
    if (coverEditionId != null && coverEditionId!.isNotEmpty) {
      urls.add('https://covers.openlibrary.org/b/olid/$coverEditionId-M.jpg');
    }

    // Then try work cover ID
    if (coverImageId != null) {
      urls.add('https://covers.openlibrary.org/b/id/$coverImageId-M.jpg');
    }

    // Fallback to generic edition ID if different from coverEditionId
    if (editionId.isNotEmpty && editionId != coverEditionId) {
      urls.add('https://covers.openlibrary.org/b/olid/$editionId-M.jpg');
    }

    // Finally try explicitly provided coverUrl
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      urls.add(coverUrl!);
    }

    return urls;
  }

  /// Get author names as a single string
  String get authorsString => authors.join(', ');
}
