import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/book.dart';

part 'book_model.freezed.dart';
part 'book_model.g.dart';

/// Book model with JSON serialization
@freezed
abstract class BookModel with _$BookModel {
  const BookModel._();

  const factory BookModel({
    required String editionId,
    required String workId,
    required String title,
    @Default([]) List<String> authors,
    String? coverUrl,
    int? coverImageId,
    String? coverEditionId, // Edition ID specifically for cover lookups
    String? publishDate,
    String? publisher,
    int? numberOfPages,
    @Default([]) List<String> isbn,
    String? description,
    String? availability,
    String? iaId,
    DateTime? addedDate,
    DateTime? lastModified,
    @Default(false) bool needsRedirectCheck, // Flag for potential redirected works
  }) = _BookModel;

  /// Convert to domain entity
  Book toEntity() {
    return Book(
      editionId: editionId,
      workId: workId,
      title: title,
      authors: authors,
      coverUrl: coverUrl,
      coverImageId: coverImageId,
      coverEditionId: coverEditionId,
      publishDate: publishDate,
      publisher: publisher,
      numberOfPages: numberOfPages,
      isbn: isbn,
      description: description,
      availability: availability,
      iaId: iaId,
      addedDate: addedDate,
      lastModified: lastModified,
    );
  }

  /// Create from domain entity
  factory BookModel.fromEntity(Book book) {
    return BookModel(
      editionId: book.editionId,
      workId: book.workId,
      title: book.title,
      authors: book.authors,
      coverUrl: book.coverUrl,
      coverImageId: book.coverImageId,
      coverEditionId: book.coverEditionId,
      publishDate: book.publishDate,
      publisher: book.publisher,
      numberOfPages: book.numberOfPages,
      isbn: book.isbn,
      description: book.description,
      availability: book.availability,
      iaId: book.iaId,
      addedDate: book.addedDate,
      lastModified: book.lastModified,
    );
  }

  /// Create from OpenLibrary API JSON
  factory BookModel.fromJson(Map<String, dynamic> json) => _$BookModelFromJson(json);

  /// Create from OpenLibrary shelf data
  factory BookModel.fromShelfData(Map<String, dynamic> data) {
    // The data structure is: { work: {...}, logged_edition: null, logged_date: "..." }
    final workData = data['work'] as Map<String, dynamic>?;

    // Extract work ID
    String workId = '';
    if (workData != null && workData['key'] != null) {
      workId = (workData['key'] as String).replaceFirst('/works/', '');
    }

    // Extract edition ID and cover - prefer logged_edition, fallback to lending_edition_s or cover_edition_key
    String editionId = '';
    int? coverImageId;
    String? coverEditionId; // Edition ID specifically for cover lookups

    // Extract edition ID from logged_edition (always a string like "/books/OL47689995M")
    if (data['logged_edition'] != null && data['logged_edition'] is String) {
      editionId = (data['logged_edition'] as String).replaceFirst('/books/', '');
    }

    // Fallback to lending edition or cover edition from work data
    if (editionId.isEmpty && workData != null) {
      editionId = workData['lending_edition_s'] as String? ??
                  workData['cover_edition_key'] as String? ??
                  '';
    }

    // Determine which edition to use for cover lookup
    // Priority: logged_edition (user's specific edition) > cover_edition_key > lending_edition_s
    if (editionId.isNotEmpty) {
      // Use the logged edition (the edition the user added to their shelf)
      coverEditionId = editionId;
    } else if (workData != null) {
      // Fall back to cover_edition_key if available
      if (workData['cover_edition_key'] != null) {
        coverEditionId = workData['cover_edition_key'] as String?;
      }
      // Or lending_edition_s as last resort
      else if (workData['lending_edition_s'] != null) {
        coverEditionId = workData['lending_edition_s'] as String?;
      }
    }

    // Get work cover ID as final fallback
    if (workData != null && workData['cover_id'] != null) {
      // Handle both int and num types from JSON
      final coverId = workData['cover_id'];
      if (coverId is int) {
        coverImageId = coverId;
      } else if (coverId is num) {
        coverImageId = coverId.toInt();
      }
    }

    // Extract title
    String title = 'Unknown Title';
    if (workData != null && workData['title'] != null) {
      title = workData['title'] as String;
    }

    // Extract authors
    List<String> authors = [];
    if (workData != null && workData['author_names'] != null) {
      authors = (workData['author_names'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // Detect potential redirect: work has ID but missing most/all metadata
    // This happens when a work has been merged/redirected to another work
    final needsRedirectCheck = workId.isNotEmpty &&
        workData != null &&
        (workData['title'] == null || (workData['title'] as String?)?.isEmpty == true) &&
        (workData['author_names'] == null || (workData['author_names'] as List).isEmpty) &&
        workData['cover_id'] == null;

    // Extract Internet Archive ID (not available in shelf data, fetched from edition details when needed)
    String? iaId;

    // Extract publication date (usually first_publish_year from work data)
    String? publishDate;
    if (workData != null) {
      // Try first_publish_year (most common in shelf data)
      if (workData['first_publish_year'] != null) {
        publishDate = workData['first_publish_year'].toString();
      }
      // Fallback to publish_date if available
      else if (workData['publish_date'] != null) {
        publishDate = workData['publish_date'].toString();
      }
    }

    return BookModel(
      editionId: editionId,
      workId: workId,
      title: title,
      authors: authors,
      coverImageId: coverImageId,
      coverEditionId: coverEditionId,
      iaId: iaId,
      publishDate: publishDate,
      addedDate: _parseDate(data['logged_date']),
      lastModified: _parseDate(data['updated']),
      needsRedirectCheck: needsRedirectCheck,
    );
  }

  /// Create from OpenLibrary work API data
  factory BookModel.fromWorkData(Map<String, dynamic> data) {
    // Extract work ID
    String workId = '';
    if (data['key'] != null) {
      workId = (data['key'] as String).replaceFirst('/works/', '');
    }

    // Extract title
    String title = data['title'] as String? ?? 'Unknown Title';

    // Extract authors from author field (array of author objects)
    List<String> authors = [];
    if (data['authors'] != null && data['authors'] is List) {
      final authorsList = data['authors'] as List;
      authors = authorsList
          .where((a) => a is Map && a['author'] != null)
          .map((a) {
            final authorData = a['author'] as Map;
            return authorData['key'] as String? ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
    }

    // Extract cover ID
    int? coverImageId;
    if (data['covers'] != null && data['covers'] is List) {
      final covers = data['covers'] as List;
      if (covers.isNotEmpty && covers[0] is int) {
        coverImageId = covers[0] as int;
      }
    }

    // Extract first publish date
    String? publishDate;
    if (data['first_publish_date'] != null) {
      publishDate = data['first_publish_date'] as String;
    }

    // Extract description
    String? description;
    if (data['description'] != null) {
      if (data['description'] is String) {
        description = data['description'] as String;
      } else if (data['description'] is Map && data['description']['value'] != null) {
        description = data['description']['value'] as String;
      }
    }

    // For works, we don't have a specific edition ID, so use work ID as placeholder
    return BookModel(
      editionId: '', // Will be populated when we fetch edition details
      workId: workId,
      title: title,
      authors: authors,
      coverImageId: coverImageId,
      publishDate: publishDate,
      description: description,
    );
  }

  /// Create from OpenLibrary edition API data
  factory BookModel.fromEditionData(Map<String, dynamic> data) {
    // Extract edition ID
    String editionId = '';
    if (data['key'] != null) {
      editionId = (data['key'] as String).replaceFirst('/books/', '');
    }

    // Extract work ID from works array
    String workId = '';
    if (data['works'] != null && data['works'] is List) {
      final works = data['works'] as List;
      if (works.isNotEmpty) {
        final work = works[0];
        if (work is Map && work['key'] != null) {
          workId = (work['key'] as String).replaceFirst('/works/', '');
        }
      }
    }

    // Extract title (prefer 'title', fallback to first 'other_titles')
    String title = 'Unknown Title';
    if (data['title'] != null) {
      title = data['title'] as String;
    } else if (data['other_titles'] != null && data['other_titles'] is List) {
      final otherTitles = data['other_titles'] as List;
      if (otherTitles.isNotEmpty) {
        title = otherTitles[0] as String;
      }
    }

    // Extract authors from authors array
    List<String> authors = [];
    if (data['authors'] != null && data['authors'] is List) {
      final authorsList = data['authors'] as List;
      authors = authorsList
          .where((a) => a is Map && a['key'] != null)
          .map((a) {
            final authorData = a as Map;
            return authorData['key'] as String;
          })
          .toList();
    }

    // Extract cover ID
    int? coverImageId;
    if (data['covers'] != null && data['covers'] is List) {
      final covers = data['covers'] as List;
      if (covers.isNotEmpty && covers[0] is int) {
        coverImageId = covers[0] as int;
      }
    }

    // Extract publisher (first from publishers array)
    String? publisher;
    if (data['publishers'] != null && data['publishers'] is List) {
      final publishers = data['publishers'] as List;
      if (publishers.isNotEmpty) {
        publisher = publishers[0] as String;
      }
    }

    // Extract publish date
    String? publishDate;
    if (data['publish_date'] != null) {
      publishDate = data['publish_date'] as String;
    }

    // Extract number of pages
    int? numberOfPages;
    if (data['number_of_pages'] != null) {
      numberOfPages = data['number_of_pages'] as int;
    }

    // Extract ISBNs
    List<String> isbn = [];
    if (data['isbn_10'] != null && data['isbn_10'] is List) {
      isbn.addAll((data['isbn_10'] as List).map((e) => e.toString()));
    }
    if (data['isbn_13'] != null && data['isbn_13'] is List) {
      isbn.addAll((data['isbn_13'] as List).map((e) => e.toString()));
    }

    // Extract description
    String? description;
    if (data['description'] != null) {
      if (data['description'] is String) {
        description = data['description'] as String;
      } else if (data['description'] is Map && data['description']['value'] != null) {
        description = data['description']['value'] as String;
      }
    }

    // Extract Internet Archive ID
    String? iaId;
    if (data['ocaid'] != null) {
      iaId = data['ocaid'] as String;
    }

    return BookModel(
      editionId: editionId,
      workId: workId,
      title: title,
      authors: authors,
      coverImageId: coverImageId,
      coverEditionId: editionId, // Use edition ID for cover lookups
      publishDate: publishDate,
      publisher: publisher,
      numberOfPages: numberOfPages,
      isbn: isbn,
      description: description,
      iaId: iaId,
    );
  }

  /// Create from OpenLibrary search API result
  factory BookModel.fromSearchResult(Map<String, dynamic> data) {
    // Extract work ID from key
    String workId = '';
    if (data['key'] != null) {
      workId = (data['key'] as String).replaceFirst('/works/', '');
    }

    // Extract edition ID (use cover_edition_key or first from edition_key array)
    String editionId = '';
    if (data['cover_edition_key'] != null) {
      editionId = data['cover_edition_key'] as String;
    } else if (data['edition_key'] != null && data['edition_key'] is List) {
      final editionKeys = data['edition_key'] as List;
      if (editionKeys.isNotEmpty) {
        editionId = editionKeys[0] as String;
      }
    }

    // Extract title
    String title = data['title'] as String? ?? 'Unknown Title';

    // Extract authors from author_name array
    List<String> authors = [];
    if (data['author_name'] != null && data['author_name'] is List) {
      authors = (data['author_name'] as List)
          .map((name) => name as String)
          .toList();
    }

    // Extract cover image ID
    int? coverImageId;
    if (data['cover_i'] != null) {
      coverImageId = data['cover_i'] as int;
    }

    // Extract cover edition key
    String? coverEditionId;
    if (data['cover_edition_key'] != null) {
      coverEditionId = data['cover_edition_key'] as String;
    }

    // Extract publish date
    String? publishDate;
    if (data['first_publish_year'] != null) {
      publishDate = data['first_publish_year'].toString();
    }

    // Extract publisher (first from array)
    String? publisher;
    if (data['publisher'] != null && data['publisher'] is List) {
      final publishers = data['publisher'] as List;
      if (publishers.isNotEmpty) {
        publisher = publishers[0] as String;
      }
    }

    // Extract number of pages
    int? numberOfPages;
    if (data['number_of_pages_median'] != null) {
      numberOfPages = data['number_of_pages_median'] as int;
    }

    // Extract ISBNs
    List<String> isbn = [];
    if (data['isbn'] != null && data['isbn'] is List) {
      isbn = (data['isbn'] as List)
          .map((i) => i as String)
          .toList();
    }

    // Extract description from first_sentence
    String? description;
    if (data['first_sentence'] != null) {
      if (data['first_sentence'] is List) {
        final sentences = data['first_sentence'] as List;
        if (sentences.isNotEmpty) {
          description = sentences[0] as String;
        }
      } else if (data['first_sentence'] is String) {
        description = data['first_sentence'] as String;
      }
    }

    // Extract Internet Archive ID (first from array)
    String? iaId;
    if (data['ia'] != null && data['ia'] is List) {
      final iaIds = data['ia'] as List;
      if (iaIds.isNotEmpty) {
        iaId = iaIds[0] as String;
      }
    }

    // Extract availability
    String? availability;
    if (data['availability'] != null && data['availability'] is Map) {
      final avail = data['availability'] as Map;
      if (avail['status'] != null) {
        availability = avail['status'] as String;
      }
    }

    return BookModel(
      editionId: editionId,
      workId: workId,
      title: title,
      authors: authors,
      coverImageId: coverImageId,
      coverEditionId: coverEditionId,
      publishDate: publishDate,
      publisher: publisher,
      numberOfPages: numberOfPages,
      isbn: isbn,
      description: description,
      availability: availability,
      iaId: iaId,
    );
  }

  /// Parse date string to DateTime
  /// Handles OpenLibrary's custom format: "2021/03/14, 21:21:48"
  static DateTime? _parseDate(dynamic date) {
    if (date == null) {
      return null;
    }
    if (date is DateTime) {
      return date;
    }
    if (date is String) {
      try {
        // OpenLibrary uses format: "2021/03/14, 21:21:48"
        // Convert to ISO format: "2021-03-14 21:21:48"
        String normalized = date
            .replaceAll('/', '-')  // Replace slashes with hyphens
            .replaceAll(',', '');   // Remove comma

        final parsed = DateTime.parse(normalized);
        return parsed;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
