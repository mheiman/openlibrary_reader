import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/logging_service.dart';
import '../../../authentication/data/datasources/auth_remote_data_source.dart';
import '../models/book_details_model.dart';
import '../models/edition_model.dart';

/// Remote data source for book details
@lazySingleton
class BookDetailsRemoteDataSource {
  final DioClient dioClient;
  final AuthRemoteDataSource authDataSource;

  BookDetailsRemoteDataSource(this.dioClient, this.authDataSource);

  /// Fetch book details by edition ID
  Future<BookDetailsModel> fetchBookDetails({
    required String editionId,
  }) async {
    try {
      final url = '${ApiConstants.openLibraryBaseUrl}${ApiConstants.booksEndpoint}/$editionId.json';

      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        return BookDetailsModel.fromEditionApi(response.data);
      } else {
        throw ServerException(
          'Failed to fetch book details: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Book not found');
      }
      throw NetworkException(e.message ?? 'Network error fetching book details');
    } catch (e) {
      if (e is ServerException || e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch book details: $e');
    }
  }

  /// Fetch work details by work ID (includes description)
  Future<Map<String, dynamic>> fetchWorkDetails({
    required String workId,
  }) async {
    try {
      final url = '${ApiConstants.openLibraryBaseUrl}${ApiConstants.worksEndpoint}/$workId.json';

      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ServerException(
          'Failed to fetch work details: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Work not found');
      }
      throw NetworkException(e.message ?? 'Network error fetching work details');
    } catch (e) {
      if (e is ServerException || e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch work details: $e');
    }
  }

  /// Check if a work is a redirect and resolve to the correct work
  /// Returns a map with 'workData' and 'redirectedWorkId' (null if not redirected)
  Future<Map<String, dynamic>> resolveWorkRedirect({
    required String workId,
  }) async {
    try {
      final workData = await fetchWorkDetails(workId: workId);

      // Check if this is a redirect response
      final type = workData['type'];
      if (type is Map && type['key'] == '/type/redirect') {
        // Extract the redirect location (e.g., "/works/OL3020913W")
        final location = workData['location'] as String?;
        if (location != null && location.startsWith('/works/')) {
          final redirectedWorkId = location.replaceFirst('/works/', '');

          // Fetch the actual work data
          final actualWorkData = await fetchWorkDetails(workId: redirectedWorkId);

          // Return both the actual work data and the new work ID
          return {
            'workData': actualWorkData,
            'redirectedWorkId': redirectedWorkId,
            'originalWorkId': workId,
          };
        }
      }

      // Not a redirect, return original data
      return {
        'workData': workData,
        'redirectedWorkId': null,
        'originalWorkId': workId,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch available editions for a work
  Future<List<EditionModel>> fetchEditions({
    required String workId,
    int maxEditions = 200, // Reasonable limit to prevent excessive fetching
  }) async {
    try {
      final List<EditionModel> editions = [];
      int offset = 0;
      const limit = 50; // OpenLibrary's default page size
      bool hasMore = true;
      int totalSize = 0;

      while (hasMore && editions.length < maxEditions) {
        final url = '${ApiConstants.openLibraryBaseUrl}${ApiConstants.worksEndpoint}/$workId${ApiConstants.editionsEndpoint}?offset=$offset&limit=$limit';

        final response = await dioClient.get(url);

        if (response.statusCode == 200) {
          // Get total size from first response
          if (totalSize == 0) {
            totalSize = response.data['size'] ?? 0;
            // If total is less than or equal to limit, we only need one request
            if (totalSize <= limit) {
              hasMore = false;
            }
          }

          // Parse current page of editions
          if (response.data['entries'] != null && response.data['entries'] is List) {
            for (var entry in response.data['entries'] as List) {
              try {
                editions.add(EditionModel.fromEditionsApi(entry as Map<String, dynamic>));
                // Stop if we've reached the maximum
                if (editions.length >= maxEditions) {
                  break;
                }
              } catch (e) {
                LoggingService.error('Error parsing edition: $e');
              }
            }
          }

          // Check if we need to fetch more pages
          offset += limit;
          hasMore = offset < totalSize && editions.length < maxEditions;
        } else {
          throw ServerException(
            'Failed to fetch editions: ${response.statusMessage}',
            response.statusCode,
          );
        }
      }

      return editions;
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error fetching editions');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch editions: $e');
    }
  }

  /// Borrow a book
  Future<void> borrowBook({
    required String editionId,
    required String loanType,
  }) async {
    try {
      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Note: The actual borrowing API endpoint may vary
      // This is based on the original app's implementation
      final url = '${ApiConstants.archiveOrgBaseUrl}${ApiConstants.loanServiceEndpoint}';

      final data = {
        'action': 'create_token',
        'identifier': editionId,
        'format': 'json',
      };

      final response = await dioClient.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          'Failed to borrow book: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error borrowing book');
    } catch (e) {
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException('Failed to borrow book: $e');
    }
  }

  /// Return a borrowed book
  Future<void> returnBook({
    required String editionId,
  }) async {
    try {
      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      final url = '${ApiConstants.archiveOrgBaseUrl}${ApiConstants.loanServiceEndpoint}';

      final data = {
        'action': 'return_loan',
        'identifier': editionId,
      };

      final response = await dioClient.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to return book: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error returning book');
    } catch (e) {
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException('Failed to return book: $e');
    }
  }

  /// Get borrow status/availability for an edition
  Future<Map<String, dynamic>> getBorrowStatus({
    required String editionId,
  }) async {
    try {
      final url = '${ApiConstants.archiveOrgBaseUrl}${ApiConstants.loanServiceEndpoint}?action=availability&identifier=$editionId';

      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ServerException(
          'Failed to get borrow status: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error getting borrow status');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get borrow status: $e');
    }
  }

  /// Fetch related editions from Internet Archive API
  Future<List<String>> fetchRelatedEditionIds({
    required String iaId,
  }) async {
    try {
      final url = 'https://be-api.us.archive.org/mds/v1/get_related/all/$iaId?size=50';

      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        final List<String> relatedIds = [];
        final hits = response.data['hits']?['hits'] as List?;

        if (hits != null) {
          for (var hit in hits) {
            if (hit['_id'] != null) {
              relatedIds.add('OCAID:${hit['_id']}');
            }
          }
        }

        return relatedIds;
      } else {
        throw ServerException(
          'Failed to fetch related editions: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error fetching related editions');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch related editions: $e');
    }
  }

  /// Fetch book details for multiple books using bibkeys
  Future<List<BookDetailsModel>> fetchBooksByBibkeys({
    required List<String> bibkeys,
  }) async {
    try {
      final url = '${ApiConstants.openLibraryBaseUrl}/api/books?bibkeys=${bibkeys.join(',')}&format=json&jscmd=details';

      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        final List<BookDetailsModel> books = [];
        final data = response.data as Map<String, dynamic>;

        data.forEach((key, value) {
          try {
            final details = value['details'] as Map<String, dynamic>;
            books.add(BookDetailsModel.fromEditionApi(details));
          } catch (e) {
            LoggingService.error('Error parsing book details for $key: $e');
          }
        });

        return books;
      } else {
        throw ServerException(
          'Failed to fetch books: ${response.statusMessage}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Network error fetching books');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch books: $e');
    }
  }
}
