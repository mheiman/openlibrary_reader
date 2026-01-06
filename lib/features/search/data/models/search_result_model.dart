import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/search_result.dart';
import 'work_search_item_model.dart';

part 'search_result_model.freezed.dart';
part 'search_result_model.g.dart';

/// Model for search result from OpenLibrary API
@freezed
class SearchResultModel with _$SearchResultModel {
  const factory SearchResultModel({
    required List<WorkSearchItemModel> works,
    required int totalResults,
    @Default(1) int currentPage,
    @Default(false) bool hasMore,
  }) = _SearchResultModel;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) =>
      _$SearchResultModelFromJson(json);

  /// Parse from OpenLibrary search API response
  factory SearchResultModel.fromSearchApi({
    required Map<String, dynamic> data,
    required int currentPage,
    required int limit,
  }) {
    // Extract total results
    final totalResults = data['numFound'] as int? ?? 0;

    // Extract works
    List<WorkSearchItemModel> works = [];
    if (data['docs'] != null && data['docs'] is List) {
      works = (data['docs'] as List)
          .map((doc) => WorkSearchItemModel.fromSearchApi(doc as Map<String, dynamic>))
          .toList();
    }

    // Calculate if there are more results
    final hasMore = (currentPage * limit) < totalResults;

    return SearchResultModel(
      works: works,
      totalResults: totalResults,
      currentPage: currentPage,
      hasMore: hasMore,
    );
  }
}

/// Extension to convert model to entity
extension SearchResultModelExtension on SearchResultModel {
  SearchResult toEntity() {
    return SearchResult(
      works: works.map((w) => w.toEntity()).toList(),
      totalResults: totalResults,
      currentPage: currentPage,
      hasMore: hasMore,
    );
  }
}
