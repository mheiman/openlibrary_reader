import 'package:injectable/injectable.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/search_result_model.dart';

/// Remote data source for search operations
@lazySingleton
class SearchRemoteDataSource {
  final DioClient dioClient;

  SearchRemoteDataSource(this.dioClient);

  /// Search for books on OpenLibrary
  ///
  /// [query] - Search query string
  /// [page] - Page number (1-indexed)
  /// [limit] - Results per page
  /// [sort] - Optional sort parameter
  Future<SearchResultModel> searchBooks({
    required String query,
    required int page,
    required int limit,
    String? sort,
  }) async {
    // Calculate offset for pagination
    final offset = (page - 1) * limit;

    // Add has_fulltext:true to query to only show readable books
    final fullQuery = '$query ebook_access:[borrowable TO *]';

    // Build query parameters
    final queryParams = {
      'q': fullQuery,
      'offset': offset.toString(),
      'limit': limit.toString(),
      'fields': [
        'key',
        'title',
        'author_name',
        'author_key',
        'first_publish_year',
        'cover_i',
        'ebook_access',
        'ebook_count_i',
        'lending_edition_s',
        'availability',
        'subject',
      ].join(','),
    };

    // Add sort parameter if provided
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }

    // Make API request
    final response = await dioClient.get(
      '${ApiConstants.openLibraryBaseUrl}${ApiConstants.searchEndpoint}',
      queryParameters: queryParams,
    );

    // Parse response
    return SearchResultModel.fromSearchApi(
      data: response.data as Map<String, dynamic>,
      currentPage: page,
      limit: limit,
    );
  }
}
