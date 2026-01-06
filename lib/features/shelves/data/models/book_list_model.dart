import '../../domain/entities/book_list.dart';

/// Model for BookList API response
class BookListModel {
  final String url;
  final String fullUrl;
  final String name;
  final int seedCount;
  final String lastUpdate;

  BookListModel({
    required this.url,
    required this.fullUrl,
    required this.name,
    required this.seedCount,
    required this.lastUpdate,
  });

  /// Create from JSON
  factory BookListModel.fromJson(Map<String, dynamic> json) {
    return BookListModel(
      url: json['url'] as String? ?? '',
      fullUrl: json['full_url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      seedCount: json['seed_count'] as int? ?? 0,
      lastUpdate: json['last_update'] as String? ?? '',
    );
  }

  /// Convert to entity
  BookList toEntity() {
    // Parse the last_update string to DateTime
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(lastUpdate);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return BookList(
      url: url,
      fullUrl: fullUrl,
      name: name,
      seedCount: seedCount,
      lastUpdate: parsedDate,
    );
  }
}

/// Model for the lists API response
class BookListsResponseModel {
  final int size;
  final List<BookListModel> entries;

  BookListsResponseModel({
    required this.size,
    required this.entries,
  });

  /// Create from JSON
  factory BookListsResponseModel.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    final entries = entriesJson
        .map((e) => BookListModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return BookListsResponseModel(
      size: json['size'] as int? ?? 0,
      entries: entries,
    );
  }
}
