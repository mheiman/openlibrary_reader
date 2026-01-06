import 'package:equatable/equatable.dart';

/// Detailed book information
class BookDetails extends Equatable {
  final String editionId; // OLID
  final String workId;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final List<String> authorKeys;
  final String? description;
  final String? coverUrl;
  final int? coverImageId;
  final String? publishDate;
  final String? publisher;
  final List<String> publishers;
  final int? numberOfPages;
  final List<String> isbn10;
  final List<String> isbn13;
  final List<String> subjects;
  final String? firstSentence;
  final int? firstPublishYear;
  final String? availability;
  final String? ocaid; // Internet Archive ID (e.g., 'harrypottersorce00rowl')
  final bool? isBorrowed;
  final DateTime? loanExpiry;
  final String? loanType; // '1hour' or '14day'
  final List<String> relatedWorkIds;

  const BookDetails({
    required this.editionId,
    required this.workId,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.authorKeys = const [],
    this.description,
    this.coverUrl,
    this.coverImageId,
    this.publishDate,
    this.publisher,
    this.publishers = const [],
    this.numberOfPages,
    this.isbn10 = const [],
    this.isbn13 = const [],
    this.subjects = const [],
    this.firstSentence,
    this.firstPublishYear,
    this.availability,
    this.ocaid,
    this.isBorrowed = false,
    this.loanExpiry,
    this.loanType,
    this.relatedWorkIds = const [],
  });

  @override
  List<Object?> get props => [
        editionId,
        workId,
        title,
        subtitle,
        authors,
        authorKeys,
        description,
        coverUrl,
        coverImageId,
        publishDate,
        publisher,
        publishers,
        numberOfPages,
        isbn10,
        isbn13,
        subjects,
        firstSentence,
        firstPublishYear,
        availability,
        ocaid,
        isBorrowed,
        loanExpiry,
        loanType,
        relatedWorkIds,
      ];

  /// Get cover image URL
  String? get coverImageUrl {
    if (coverImageId != null) {
      return 'https://covers.openlibrary.org/b/id/$coverImageId-L.jpg';
    }
    return coverUrl;
  }

  /// Get author names as string
  String get authorsString => authors.join(', ');

  /// Get ISBN as string (prefer ISBN-13)
  String? get isbnString {
    if (isbn13.isNotEmpty) return isbn13.first;
    if (isbn10.isNotEmpty) return isbn10.first;
    return null;
  }

  /// Check if book can be borrowed
  bool get canBorrow {
    return availability == 'borrow_available' || availability == 'borrow';
  }

  /// Check if book is available
  bool get isAvailable {
    return availability != null && availability != 'borrow_unavailable';
  }
}
