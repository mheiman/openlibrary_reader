import '../../domain/entities/list_seed.dart';

/// Data model for ListSeed with JSON serialization
class ListSeedModel {
  final String url;
  final String type;
  final String? title;
  final String? name;
  final int? coverImageId;
  final DateTime? lastUpdate;

  const ListSeedModel({
    required this.url,
    required this.type,
    this.title,
    this.name,
    this.coverImageId,
    this.lastUpdate,
  });

  /// Create from JSON response
  factory ListSeedModel.fromJson(Map<String, dynamic> json) {
    // Extract type from URL (e.g., "/works/OL123W" -> "work")
    final url = json['url'] as String? ?? '';
    final type = _extractTypeFromUrl(url);

    // Parse cover image ID from covers array if present
    int? coverImageId;
    if (json['covers'] != null && json['covers'] is List) {
      final covers = json['covers'] as List;
      if (covers.isNotEmpty && covers[0] is int) {
        coverImageId = covers[0] as int;
      }
    }

    // Parse last update date
    DateTime? lastUpdate;
    if (json['last_update'] != null) {
      if (json['last_update'] is Map && json['last_update']['value'] != null) {
        lastUpdate = DateTime.tryParse(json['last_update']['value'] as String);
      } else if (json['last_update'] is String) {
        lastUpdate = DateTime.tryParse(json['last_update'] as String);
      }
    }

    return ListSeedModel(
      url: url,
      type: type,
      title: json['title'] as String?,
      name: json['name'] as String?,
      coverImageId: coverImageId,
      lastUpdate: lastUpdate,
    );
  }

  /// Extract type from URL path
  static String _extractTypeFromUrl(String url) {
    if (url.contains('/books/')) return 'edition';
    if (url.contains('/works/')) return 'work';
    if (url.contains('/authors/')) return 'author';
    if (url.contains('/subjects/')) return 'subject';
    return 'unknown';
  }

  /// Convert to domain entity
  ListSeed toEntity() {
    return ListSeed(
      url: url,
      type: type,
      title: title,
      name: name,
      coverImageId: coverImageId,
      lastUpdate: lastUpdate,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      if (title != null) 'title': title,
      if (name != null) 'name': name,
      if (coverImageId != null) 'covers': [coverImageId],
      if (lastUpdate != null) 'last_update': lastUpdate?.toIso8601String(),
    };
  }
}
