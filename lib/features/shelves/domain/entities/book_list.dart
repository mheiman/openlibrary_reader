import 'package:equatable/equatable.dart';

/// BookList entity representing a user's OpenLibrary list
class BookList extends Equatable {
  final String url; // Relative URL (e.g., "/people/username/lists/OL215301L")
  final String fullUrl; // Full URL with list name
  final String name; // Display name
  final int seedCount; // Number of items in the list
  final DateTime lastUpdate; // When the list was last updated

  const BookList({
    required this.url,
    required this.fullUrl,
    required this.name,
    required this.seedCount,
    required this.lastUpdate,
  });

  /// Get the list ID from the URL (e.g., "OL215301L")
  String get listId {
    final parts = url.split('/');
    return parts.isNotEmpty ? parts.last : '';
  }

  @override
  List<Object?> get props => [url, fullUrl, name, seedCount, lastUpdate];
}
