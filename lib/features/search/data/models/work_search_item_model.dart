import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/search_result.dart';

part 'work_search_item_model.freezed.dart';
part 'work_search_item_model.g.dart';

/// Model for work search item from OpenLibrary API
@freezed
abstract class WorkSearchItemModel with _$WorkSearchItemModel {
  const factory WorkSearchItemModel({
    required String workId,
    required String title,
    @Default([]) List<String> authors,
    @Default([]) List<String> authorKeys,
    int? firstPublishYear,
    int? ebookCount,
    String? coverImageId,
    String? lendingEdition,
    String? availability,
    @Default([]) List<String> subjects,
  }) = _WorkSearchItemModel;

  factory WorkSearchItemModel.fromJson(Map<String, dynamic> json) =>
      _$WorkSearchItemModelFromJson(json);

  /// Parse from OpenLibrary search API response
  factory WorkSearchItemModel.fromSearchApi(Map<String, dynamic> data) {
    // Extract work ID from key
    String workId = '';
    if (data['key'] != null) {
      workId = (data['key'] as String).replaceFirst('/works/', '');
    }

    // Extract authors
    List<String> authors = [];
    if (data['author_name'] != null && data['author_name'] is List) {
      authors = (data['author_name'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // Extract author keys
    List<String> authorKeys = [];
    if (data['author_key'] != null && data['author_key'] is List) {
      authorKeys = (data['author_key'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // Extract cover ID
    String? coverImageId;
    if (data['cover_i'] != null) {
      coverImageId = data['cover_i'].toString();
    }

    // Extract lending edition
    String? lendingEdition;
    if (data['lending_edition_s'] != null) {
      lendingEdition = data['lending_edition_s'].toString();
    }

    // Extract availability
    String? availability;
    if (data['availability'] != null && data['availability'] is Map) {
      availability = data['availability']['status']?.toString();
    }

    // Extract subjects (limit to first 10)
    List<String> subjects = [];
    if (data['subject'] != null && data['subject'] is List) {
      subjects = (data['subject'] as List)
          .take(10)
          .map((e) => e.toString())
          .toList();
    }

    return WorkSearchItemModel(
      workId: workId,
      title: data['title']?.toString() ?? '',
      authors: authors,
      authorKeys: authorKeys,
      firstPublishYear: data['first_publish_year'] as int?,
      ebookCount: data['ebook_count_i'] as int?,
      coverImageId: coverImageId,
      lendingEdition: lendingEdition,
      availability: availability,
      subjects: subjects,
    );
  }
}

/// Extension to convert model to entity
extension WorkSearchItemModelExtension on WorkSearchItemModel {
  WorkSearchItem toEntity() {
    return WorkSearchItem(
      workId: workId,
      title: title,
      authors: authors,
      authorKeys: authorKeys,
      firstPublishYear: firstPublishYear,
      ebookCount: ebookCount,
      coverImageId: coverImageId,
      lendingEdition: lendingEdition,
      availability: availability,
      subjects: subjects,
    );
  }
}
