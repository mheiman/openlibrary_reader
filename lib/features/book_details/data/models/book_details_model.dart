import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/book_details.dart';

part 'book_details_model.freezed.dart';
part 'book_details_model.g.dart';

/// Book details model with JSON serialization
@freezed
abstract class BookDetailsModel with _$BookDetailsModel {
  const BookDetailsModel._();

  const factory BookDetailsModel({
    required String editionId,
    required String workId,
    required String title,
    String? subtitle,
    @Default([]) List<String> authors,
    @Default([]) List<String> authorKeys,
    String? description,
    String? coverUrl,
    int? coverImageId,
    String? publishDate,
    String? publisher,
    @Default([]) List<String> publishers,
    int? numberOfPages,
    @Default([]) List<String> isbn10,
    @Default([]) List<String> isbn13,
    @Default([]) List<String> subjects,
    String? firstSentence,
    int? firstPublishYear,
    String? availability,
    String? ocaid, // Internet Archive ID
    @Default(false) bool isBorrowed,
    DateTime? loanExpiry,
    String? loanType,
    @Default([]) List<String> relatedWorkIds,
  }) = _BookDetailsModel;

  /// Convert to domain entity
  BookDetails toEntity() {
    return BookDetails(
      editionId: editionId,
      workId: workId,
      title: title,
      subtitle: subtitle,
      authors: authors,
      authorKeys: authorKeys,
      description: description,
      coverUrl: coverUrl,
      coverImageId: coverImageId,
      publishDate: publishDate,
      publisher: publisher,
      publishers: publishers,
      numberOfPages: numberOfPages,
      isbn10: isbn10,
      isbn13: isbn13,
      subjects: subjects,
      firstSentence: firstSentence,
      firstPublishYear: firstPublishYear,
      availability: availability,
      ocaid: ocaid,
      isBorrowed: isBorrowed,
      loanExpiry: loanExpiry,
      loanType: loanType,
      relatedWorkIds: relatedWorkIds,
    );
  }

  /// Create from JSON
  factory BookDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$BookDetailsModelFromJson(json);

  /// Create from OpenLibrary edition API response
  factory BookDetailsModel.fromEditionApi(Map<String, dynamic> data) {
    // Extract work ID
    String workId = '';
    if (data['works'] != null && data['works'] is List && (data['works'] as List).isNotEmpty) {
      final work = (data['works'] as List).first;
      if (work is Map && work['key'] != null) {
        workId = (work['key'] as String).replaceFirst('/works/', '');
      }
    }

    // Extract edition ID
    String editionId = '';
    if (data['key'] != null) {
      editionId = (data['key'] as String).replaceFirst('/books/', '');
    }

    // Extract authors
    final List<String> authors = [];
    final List<String> authorKeys = [];
    if (data['authors'] != null && data['authors'] is List) {
      for (var author in data['authors'] as List) {
        if (author is Map) {
          // Extract author name if available
          if (author['name'] != null) {
            authors.add(author['name'] as String);
          }
          // Extract author key
          if (author['key'] != null) {
            authorKeys.add((author['key'] as String).replaceFirst('/authors/', ''));
          }
        }
      }
    }

    // Extract covers
    int? coverImageId;
    if (data['covers'] != null && data['covers'] is List && (data['covers'] as List).isNotEmpty) {
      coverImageId = (data['covers'] as List).first as int?;
    }

    // Extract publishers
    final List<String> publishers = [];
    if (data['publishers'] != null && data['publishers'] is List) {
      publishers.addAll((data['publishers'] as List).map((p) => p.toString()));
    }

    // Extract ISBNs
    final List<String> isbn10 = [];
    final List<String> isbn13 = [];
    if (data['isbn_10'] != null && data['isbn_10'] is List) {
      isbn10.addAll((data['isbn_10'] as List).map((i) => i.toString()));
    }
    if (data['isbn_13'] != null && data['isbn_13'] is List) {
      isbn13.addAll((data['isbn_13'] as List).map((i) => i.toString()));
    }

    // Extract subjects
    final List<String> subjects = [];
    if (data['subjects'] != null && data['subjects'] is List) {
      subjects.addAll((data['subjects'] as List).map((s) => s.toString()));
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

    // Extract ocaid (Internet Archive ID)
    String? ocaid;
    if (data['ocaid'] != null) {
      ocaid = data['ocaid'] as String?;
    }

    return BookDetailsModel(
      editionId: editionId,
      workId: workId,
      title: data['title'] as String? ?? 'Unknown Title',
      subtitle: data['subtitle'] as String?,
      authors: authors,
      authorKeys: authorKeys,
      description: description,
      coverImageId: coverImageId,
      publishDate: data['publish_date'] as String?,
      publisher: publishers.isNotEmpty ? publishers.first : null,
      publishers: publishers,
      numberOfPages: data['number_of_pages'] as int?,
      isbn10: isbn10,
      isbn13: isbn13,
      subjects: subjects,
      ocaid: ocaid,
    );
  }
}
