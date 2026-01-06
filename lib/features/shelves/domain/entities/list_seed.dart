import 'package:equatable/equatable.dart';

/// ListSeed entity representing an item in a user's list
/// Seeds can be editions, works, authors, or subjects
class ListSeed extends Equatable {
  final String url; // Relative URL (e.g., "/works/OL45804W", "/books/OL7353617M")
  final String type; // "edition", "work", "author", "subject"
  final String? title; // For editions/works
  final String? name; // For authors/subjects
  final int? coverImageId; // Cover ID for books/works
  final DateTime? lastUpdate; // When the seed was last updated

  const ListSeed({
    required this.url,
    required this.type,
    this.title,
    this.name,
    this.coverImageId,
    this.lastUpdate,
  });

  /// Extract the OpenLibrary ID from the URL (e.g., "OL45804W")
  String get olid {
    final parts = url.split('/');
    return parts.isNotEmpty ? parts.last : '';
  }

  /// Check if this seed is a book (edition or work)
  bool get isBook => type == 'edition' || type == 'work';

  /// Check if this seed is an edition
  bool get isEdition => type == 'edition';

  /// Check if this seed is a work
  bool get isWork => type == 'work';

  /// Check if this seed is an author
  bool get isAuthor => type == 'author';

  /// Check if this seed is a subject
  bool get isSubject => type == 'subject';

  /// Get display name (title for books, name for authors/subjects)
  String get displayName => title ?? name ?? 'Unknown';

  @override
  List<Object?> get props => [url, type, title, name, coverImageId, lastUpdate];
}
