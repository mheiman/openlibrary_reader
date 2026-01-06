import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/edition.dart';

part 'edition_model.freezed.dart';
part 'edition_model.g.dart';

/// Edition model with JSON serialization
@freezed
class EditionModel with _$EditionModel {
  const EditionModel._();

  const factory EditionModel({
    required String editionId,
    required String title,
    String? publishDate,
    String? publisher,
    int? numberOfPages,
    @Default([]) List<String> isbn,
    int? coverImageId,
    String? coverEditionKey,
    String? format,
    String? availability,
  }) = _EditionModel;

  /// Convert to domain entity
  Edition toEntity() {
    return Edition(
      editionId: editionId,
      title: title,
      publishDate: publishDate,
      publisher: publisher,
      numberOfPages: numberOfPages,
      isbn: isbn,
      coverImageId: coverImageId,
      coverEditionKey: coverEditionKey,
      format: format,
      availability: availability,
    );
  }

  /// Create from JSON
  factory EditionModel.fromJson(Map<String, dynamic> json) =>
      _$EditionModelFromJson(json);

  /// Create from OpenLibrary editions API response
  factory EditionModel.fromEditionsApi(Map<String, dynamic> data) {
    // Extract edition ID
    String editionId = '';
    if (data['key'] != null) {
      editionId = (data['key'] as String).replaceFirst('/books/', '');
    }

    // Extract cover - try multiple fields according to OpenLibrary API docs
    int? coverImageId;
    String? coverEditionKey;

    // 1. Try 'cover_i' field first (recommended by OpenLibrary API)
    if (data['cover_i'] != null) {
      coverImageId = data['cover_i'] as int?;
    }
    // 2. Try 'covers' array (check that first element is valid)
    else if (data['covers'] != null &&
             data['covers'] is List &&
             (data['covers'] as List).isNotEmpty) {
      final coverValue = (data['covers'] as List).first;
      if (coverValue is int && coverValue > 0) {
        coverImageId = coverValue;
      }
    }
    // 3. Try 'cover_id' field
    else if (data['cover_id'] != null) {
      coverImageId = data['cover_id'] as int?;
    }

    // 4. Extract 'cover_edition_key' (OLID) - used as fallback in coverImageUrl
    if (data['cover_edition_key'] != null) {
      coverEditionKey = data['cover_edition_key'] as String?;
    }

    // Extract ISBNs
    final List<String> isbns = [];
    if (data['isbn_10'] != null && data['isbn_10'] is List) {
      isbns.addAll((data['isbn_10'] as List).map((i) => i.toString()));
    }
    if (data['isbn_13'] != null && data['isbn_13'] is List) {
      isbns.addAll((data['isbn_13'] as List).map((i) => i.toString()));
    }

    // Extract publisher
    String? publisher;
    if (data['publishers'] != null && data['publishers'] is List && (data['publishers'] as List).isNotEmpty) {
      publisher = (data['publishers'] as List).first.toString();
    }

    // Extract availability information
    String? availability;
    // Check for Internet Archive ID (indicates borrowable/readable)
    if (data['ocaid'] != null && (data['ocaid'] as String).isNotEmpty) {
      availability = 'borrow';
    }
    // Check lending_identifier_s field
    else if (data['lending_identifier_s'] != null) {
      availability = 'borrow_available';
    }
    // Check for full text availability
    else if (data['has_fulltext'] == true) {
      availability = 'full';
    }
    // Check if public scan
    else if (data['public_scan_b'] == true) {
      availability = 'open';
    }
    // Check ia field
    else if (data['ia'] != null && data['ia'] is List && (data['ia'] as List).isNotEmpty) {
      availability = 'borrow';
    }

    return EditionModel(
      editionId: editionId,
      title: data['title'] as String? ?? 'Unknown Edition',
      publishDate: data['publish_date'] as String?,
      publisher: publisher,
      numberOfPages: data['number_of_pages'] as int?,
      isbn: isbns,
      coverImageId: coverImageId,
      coverEditionKey: coverEditionKey,
      format: data['physical_format'] as String?,
      availability: availability,
    );
  }
}
