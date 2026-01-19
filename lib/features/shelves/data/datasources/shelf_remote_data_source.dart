import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/logging_service.dart';
import '../../../authentication/data/datasources/auth_remote_data_source.dart';
import '../models/author_model.dart';
import '../models/book_list_model.dart';
import '../models/book_model.dart';
import '../models/list_seed_model.dart';
import '../models/shelf_model.dart';

/// Remote data source for shelf operations
@lazySingleton
class ShelfRemoteDataSource {
  final DioClient dioClient;
  final AuthRemoteDataSource authDataSource;

  ShelfRemoteDataSource(this.dioClient, this.authDataSource);

  /// Fetch shelf data from OpenLibrary API
  ///
  /// Returns list of [ShelfModel] for all configured shelves
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<List<ShelfModel>> fetchShelves({
    required List<String> shelfKeys,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      final List<ShelfModel> shelves = [];

      for (final shelfKey in shelfKeys) {
        try {
          final shelfData = await _fetchShelfData(shelfKey, cookieHeader);
          shelves.add(shelfData);
        } catch (e) {
          // If one shelf fails, continue with others
          LoggingService.error('Error fetching shelf $shelfKey: $e');
        }
      }

      return shelves;
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error fetching shelves');
    } catch (e) {
      throw ServerException('Failed to fetch shelves: $e');
    }
  }

  /// Fetch a single shelf from OpenLibrary API
  ///
  /// Returns [ShelfModel] for the requested shelf
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<ShelfModel> fetchSingleShelf({
    required String shelfKey,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      return await _fetchShelfData(shelfKey, cookieHeader);
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error fetching shelf');
    } catch (e) {
      throw ServerException('Failed to fetch shelf: $e');
    }
  }

  /// Fetch single shelf data
  Future<ShelfModel> _fetchShelfData(
    String shelfKey,
    String cookieHeader,
  ) async {
    // Get user ID from cookie
    final userId = _extractUserIdFromCookie(cookieHeader);
    if (userId.isEmpty) {
      throw const AuthException('Invalid session');
    }

    // Fetch first page to get total count
    final baseUrl = '${ApiConstants.openLibraryBaseUrl}/people/$userId/books/$shelfKey.json';
    final firstResponse = await dioClient.get(
      baseUrl,
      options: Options(
        headers: {'Cookie': cookieHeader},
      ),
    );

    if (firstResponse.statusCode != 200) {
      throw ServerException(
        'Failed to fetch shelf: ${firstResponse.statusMessage}',
        firstResponse.statusCode,
      );
    }

    // Parse first page
    final firstData = firstResponse.data as Map<String, dynamic>;
    final totalCount = firstData['numFound'] as int? ?? 0;
    final firstPageEntries = firstData['reading_log_entries'] as List? ?? [];

    // Collect all book entries
    final allEntries = List<dynamic>.from(firstPageEntries);

    // If there are more books, fetch remaining pages
    if (totalCount > firstPageEntries.length) {
      final pageSize = firstPageEntries.length; // Usually 100
      final totalPages = (totalCount / pageSize).ceil();

      LoggingService.error('DEBUG: Fetching $totalPages pages for $shelfKey (total: $totalCount books)');

      // Fetch remaining pages (starting from page 2)
      for (int page = 2; page <= totalPages; page++) {
        try {
          final pageResponse = await dioClient.get(
            '$baseUrl?page=$page',
            options: Options(
              headers: {'Cookie': cookieHeader},
            ),
          );

          if (pageResponse.statusCode == 200) {
            final pageData = pageResponse.data as Map<String, dynamic>;
            final pageEntries = pageData['reading_log_entries'] as List? ?? [];
            allEntries.addAll(pageEntries);
            LoggingService.error('DEBUG: Fetched page $page: ${pageEntries.length} books');
          }
        } catch (e) {
          LoggingService.error('Error fetching page $page for $shelfKey: $e');
          // Continue with other pages even if one fails
        }
      }
    }

    LoggingService.error('DEBUG: Total books fetched for $shelfKey: ${allEntries.length}/$totalCount');

    // Create modified response data with all entries
    final completeData = Map<String, dynamic>.from(firstData);
    completeData['reading_log_entries'] = allEntries;

    return _parseShelfResponse(completeData, shelfKey);
  }

  /// Parse shelf API response into ShelfModel
  ShelfModel _parseShelfResponse(Map<String, dynamic> data, String shelfKey) {
    final List<BookModel> books = [];

    // Parse entries (books)
    if (data['reading_log_entries'] != null) {
      final entries = data['reading_log_entries'] as List;
      for (var entry in entries) {
        try {
          final bookModel = BookModel.fromShelfData(entry as Map<String, dynamic>);
          books.add(bookModel);
        } catch (e) {
          LoggingService.error('Error parsing book entry: $e');
        }
      }
    }

    // Extract total count from API response (numFound field)
    final totalCount = data['numFound'] as int? ?? books.length;

    // Get shelf config from default shelves
    final shelfConfig = _getShelfConfig(shelfKey);

    return ShelfModel(
      key: shelfKey,
      name: shelfConfig['name'] as String,
      olName: shelfConfig['olName'] as String,
      olId: shelfConfig['olId'] as int,
      books: books,
      totalCount: totalCount,
      displayOrder: shelfConfig['displayOrder'] as int,
      lastSynced: DateTime.now(),
    );
  }

  /// Get shelf configuration by key
  Map<String, dynamic> _getShelfConfig(String key) {
    const shelfConfigs = {
      'currently-reading': {
        'name': 'Reading',
        'olName': 'Currently Reading',
        'olId': 2,
        'displayOrder': 0,
      },
      'want-to-read': {
        'name': 'To Read',
        'olName': 'Want to Read',
        'olId': 1,
        'displayOrder': 1,
      },
      'already-read': {
        'name': 'Have Read',
        'olName': 'Already Read',
        'olId': 3,
        'displayOrder': 2,
      },
    };

    return shelfConfigs[key] ?? {
      'name': key,
      'olName': key,
      'olId': 0,
      'displayOrder': 99,
    };
  }

  /// Extract user ID from cookie header
  String _extractUserIdFromCookie(String cookieHeader) {
    final RegExp userIdReg = RegExp(r'session=/people/([^%]+)%');
    if (userIdReg.hasMatch(cookieHeader)) {
      return userIdReg.firstMatch(cookieHeader)!.group(1) ?? '';
    }
    return '';
  }

  /// Move book to a different shelf via API
  ///
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<void> moveBookToShelf({
    required String workId,
    String? editionId,
    required String targetShelfKey,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Handle special case: -1 means remove from all shelves
      final int shelfId;
      if (targetShelfKey == '-1') {
        shelfId = -1;
      } else {
        final shelfConfig = _getShelfConfig(targetShelfKey);
        shelfId = shelfConfig['olId'] as int;
      }

      // OpenLibrary API call to update bookshelves
      final url = '${ApiConstants.openLibraryBaseUrl}/works/$workId/bookshelves.json';

      // Build form data - only include edition_id if provided
      final formDataMap = {
        'action': 'add',
        'redir': false,
        'bookshelf_id': shelfId,
        'dont_remove': true,
      };

      // Only add edition_id if we have a valid edition ID
      if (editionId != null && editionId.isNotEmpty) {
        formDataMap['edition_id'] = '/books/$editionId';
      }

      final formData = FormData.fromMap(formDataMap);

      LoggingService.debug('DEBUG: ===== API CALL: moveBookToShelf =====');
      LoggingService.debug('DEBUG: POST $url');
      LoggingService.debug('DEBUG: Parameters:');
      LoggingService.debug('DEBUG:   workId: $workId');
      LoggingService.debug('DEBUG:   editionId: ${editionId ?? "(null)"}');
      LoggingService.debug('DEBUG:   targetShelfKey: $targetShelfKey');
      LoggingService.debug('DEBUG:   shelfId: $shelfId');
      LoggingService.debug('DEBUG: POST Body (FormData):');
      LoggingService.debug('DEBUG:   action=add');
      LoggingService.debug('DEBUG:   redir=false');
      LoggingService.debug('DEBUG:   bookshelf_id=$shelfId');
      if (editionId != null && editionId.isNotEmpty) {
        LoggingService.debug('DEBUG:   edition_id=/books/$editionId');
      } else {
        LoggingService.debug('DEBUG:   edition_id=(omitted - no valid edition ID)');
      }
      LoggingService.debug('DEBUG:   dont_remove=true');
      LoggingService.debug('DEBUG: Headers:');
      LoggingService.debug('DEBUG:   Cookie: ${cookieHeader.substring(0, 50)}...');

      final response = await dioClient.post(
        url,
        data: formData,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      LoggingService.debug('DEBUG: Response Status: ${response.statusCode}');
      LoggingService.debug('DEBUG: Response Data: ${response.data}');
      LoggingService.debug('DEBUG: ===== API CALL SUCCESS =====');
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      LoggingService.error('DEBUG: ===== API CALL FAILED =====');
      LoggingService.error('DEBUG: DioException Type: ${e.type}');
      LoggingService.error('DEBUG: Error Message: ${e.message}');
      LoggingService.error('DEBUG: Request URL: ${e.requestOptions.uri}');
      LoggingService.error('DEBUG: Request Method: ${e.requestOptions.method}');
      LoggingService.error('DEBUG: Request Data: ${e.requestOptions.data}');
      if (e.response != null) {
        LoggingService.error('DEBUG: Response Status Code: ${e.response!.statusCode}');
        LoggingService.error('DEBUG: Response Status Message: ${e.response!.statusMessage}');
        LoggingService.error('DEBUG: Response Data: ${e.response!.data}');
        LoggingService.error('DEBUG: Response Headers: ${e.response!.headers}');
      } else {
        LoggingService.error('DEBUG: No response received (connection/timeout error)');
      }
      LoggingService.error('DEBUG: Stack Trace: ${e.stackTrace}');
      LoggingService.error('DEBUG: ===== END ERROR =====');

      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error moving book');
    } catch (e, stackTrace) {
      LoggingService.error('DEBUG: ===== UNEXPECTED ERROR =====');
      LoggingService.error('DEBUG: Exception Type: ${e.runtimeType}');
      LoggingService.error('DEBUG: Exception: $e');
      LoggingService.error('DEBUG: Stack Trace: $stackTrace');
      LoggingService.error('DEBUG: ===== END ERROR =====');
      throw ServerException('Failed to move book: $e');
    }
  }

  /// Remove book from shelf via API
  ///
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<void> removeBookFromShelf({
    required String workId,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Remove from reading log (set to no shelf)
      final url = '${ApiConstants.openLibraryBaseUrl}/account/loan';

      await dioClient.post(
        url,
        data: {
          'work_id': workId,
          'bookshelf_id': -1, // -1 means remove from all shelves
        },
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error removing book');
    } catch (e) {
      throw ServerException('Failed to remove book: $e');
    }
  }

  /// Fetch user's book lists from OpenLibrary API
  ///
  /// Returns list of [BookListModel]
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<List<BookListModel>> fetchBookLists() async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Get user ID from cookie
      final userId = _extractUserIdFromCookie(cookieHeader);
      if (userId.isEmpty) {
        throw const AuthException('Invalid session');
      }

      // Fetch lists
      final url = '${ApiConstants.openLibraryBaseUrl}/people/$userId/lists.json';
      final response = await dioClient.get(
        url,
        options: Options(
          headers: {'Cookie': cookieHeader},
        ),
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to fetch lists: ${response.statusMessage}',
          response.statusCode,
        );
      }

      // Parse response data - it might be a String or already a Map
      final Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        data = response.data as Map<String, dynamic>;
      }

      final listsResponse = BookListsResponseModel.fromJson(data);
      return listsResponse.entries;
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error fetching lists');
    } catch (e) {
      throw ServerException('Failed to fetch lists: $e');
    }
  }

  /// Fetch seeds (items) for a specific list
  ///
  /// Returns list of [ListSeedModel]
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<List<ListSeedModel>> fetchListSeeds(String listUrl) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Build seeds URL from list URL (e.g., /people/user/lists/OL123L -> /people/user/lists/OL123L/seeds.json)
      final seedsUrl = listUrl.endsWith('.json')
          ? listUrl.replaceAll('.json', '/seeds.json')
          : '$listUrl/seeds.json';

      final url = '${ApiConstants.openLibraryBaseUrl}$seedsUrl';
      final response = await dioClient.get(
        url,
        options: Options(
          headers: {'Cookie': cookieHeader},
        ),
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to fetch list seeds: ${response.statusMessage}',
          response.statusCode,
        );
      }

      // Parse response data
      final Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        data = response.data as Map<String, dynamic>;
      }

      // Extract entries array
      final List<dynamic> entriesData = data['entries'] as List<dynamic>? ?? [];

      // Convert to models
      final seeds = entriesData
          .whereType<Map<String, dynamic>>()
          .map((entry) => ListSeedModel.fromJson(entry))
          .toList();

      return seeds;
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error fetching list seeds');
    } catch (e) {
      throw ServerException('Failed to fetch list seeds: $e');
    }
  }

  /// Convert a list seed to a Book entity
  ///
  /// For editions: fetches edition details directly
  /// For works: fetches work details and gets first available edition
  /// Returns null if conversion fails or seed type is not supported
  Future<BookModel?> convertSeedToBook(ListSeedModel seed) async {
    try {
      if (seed.type == 'edition') {
        // Fetch edition details
        final url = '${ApiConstants.openLibraryBaseUrl}${seed.url}.json';
        final response = await dioClient.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }

        return BookModel.fromEditionData(data);
      } else if (seed.type == 'work') {
        // Fetch work details to get first edition
        final url = '${ApiConstants.openLibraryBaseUrl}${seed.url}.json';
        final response = await dioClient.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }

        // Try to get first edition from work
        String? editionKey;
        if (data['editions'] != null && data['editions'] is List) {
          final editions = data['editions'] as List;
          if (editions.isNotEmpty) {
            editionKey = editions[0] is String
                ? editions[0] as String
                : (editions[0] as Map)['key'] as String?;
          }
        }

        if (editionKey == null) {
          // Create a minimal book from work data
          return BookModel.fromWorkData(data);
        }

        // Fetch the edition details
        final editionUrl = '${ApiConstants.openLibraryBaseUrl}$editionKey.json';
        final editionResponse = await dioClient.get(editionUrl);

        if (editionResponse.statusCode != 200) {
          // Fall back to work data
          return BookModel.fromWorkData(data);
        }

        final Map<String, dynamic> editionData;
        if (editionResponse.data is String) {
          editionData =
              jsonDecode(editionResponse.data as String) as Map<String, dynamic>;
        } else {
          editionData = editionResponse.data as Map<String, dynamic>;
        }

        return BookModel.fromJson(editionData);
      }

      // Unsupported seed type (author, subject, etc.)
      return null;
    } catch (e) {
      LoggingService.error('Error converting seed to book: $e');
      return null;
    }
  }

  /// Batch fetch books from list seeds using optimized API calls
  ///
  /// Uses Search API for work seeds and Books API for edition seeds
  /// to minimize API calls and get complete author information
  Future<List<BookModel>> fetchBooksFromSeeds(List<ListSeedModel> seeds) async {
    try {
      // Separate seeds by type
      final workSeeds = seeds.where((s) => s.type == 'work').toList();
      final editionSeeds = seeds.where((s) => s.type == 'edition').toList();

      // Fetch both types in parallel
      final results = await Future.wait([
        _batchFetchWorks(workSeeds),
        _batchFetchEditions(editionSeeds),
      ]);

      // Combine results
      return [...results[0], ...results[1]];
    } catch (e) {
      LoggingService.error('Error batch fetching books from seeds: $e');
      rethrow;
    }
  }

  /// Batch fetch works using Search API
  Future<List<BookModel>> _batchFetchWorks(List<ListSeedModel> workSeeds) async {
    if (workSeeds.isEmpty) return [];

    final books = <BookModel>[];

    // Define fields we need from search API
    const fields = 'key,title,author_name,cover_i,cover_edition_key,'
        'edition_key,first_publish_year,publisher,number_of_pages_median,'
        'isbn,first_sentence,availability,ia';

    // Process in batches of 50 to stay under URL length limits
    const batchSize = 50;
    for (var i = 0; i < workSeeds.length; i += batchSize) {
      final batch = workSeeds.skip(i).take(batchSize).toList();

      // Build OR query: key:(/works/OL123W OR /works/OL456W OR ...)
      final keys = batch.map((s) => s.url).join(' OR ');
      final query = Uri.encodeComponent('key:($keys)');

      final url = '${ApiConstants.openLibraryBaseUrl}/search.json?q=$query&fields=$fields';

      try {
        final response = await dioClient.get(url);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data;
          if (response.data is String) {
            data = jsonDecode(response.data as String) as Map<String, dynamic>;
          } else {
            data = response.data as Map<String, dynamic>;
          }

          // Parse docs array
          final List<dynamic> docs = data['docs'] as List<dynamic>? ?? [];
          for (final doc in docs) {
            if (doc is Map<String, dynamic>) {
              try {
                books.add(BookModel.fromSearchResult(doc));
              } catch (e) {
                LoggingService.error('Error parsing search result: $e');
              }
            }
          }
        }
      } catch (e) {
        LoggingService.error('Error fetching work batch: $e');
        // Continue with next batch
      }
    }

    return books;
  }

  /// Batch fetch editions using Books API
  Future<List<BookModel>> _batchFetchEditions(List<ListSeedModel> editionSeeds) async {
    if (editionSeeds.isEmpty) return [];

    final books = <BookModel>[];

    // Process in batches of 25 (Books API is more reliable with smaller batches)
    const batchSize = 25;
    for (var i = 0; i < editionSeeds.length; i += batchSize) {
      final batch = editionSeeds.skip(i).take(batchSize).toList();

      // Extract edition IDs (e.g., /books/OL123M -> OL123M)
      final bibkeys = batch
          .map((s) => s.url.replaceFirst('/books/', ''))
          .join(',');

      final url = '${ApiConstants.openLibraryBaseUrl}/api/books'
          '?bibkeys=$bibkeys&jscmd=details&format=json';

      try {
        final response = await dioClient.get(url);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data;
          if (response.data is String) {
            data = jsonDecode(response.data as String) as Map<String, dynamic>;
          } else {
            data = response.data as Map<String, dynamic>;
          }

          // Parse each book in the response
          for (final entry in data.entries) {
            if (entry.value is Map<String, dynamic>) {
              try {
                final bookData = entry.value as Map<String, dynamic>;

                // Convert Books API format to BookModel
                // The Books API returns data in a different structure
                final book = _bookModelFromBooksApi(entry.key, bookData);
                if (book != null) {
                  books.add(book);
                }
              } catch (e) {
                LoggingService.error('Error parsing books API result for ${entry.key}: $e');
              }
            }
          }
        }
      } catch (e) {
        LoggingService.error('Error fetching edition batch: $e');
        // Continue with next batch
      }
    }

    return books;
  }

  /// Convert Books API response to BookModel
  /// Handles jscmd=details format where most fields are nested under 'details'
  BookModel? _bookModelFromBooksApi(String bibkey, Map<String, dynamic> data) {
    try {
      LoggingService.error('DEBUG: Parsing book $bibkey');
      LoggingService.error('DEBUG: Keys in data: ${data.keys.toList()}');

      // Extract edition ID from bibkey (already just the ID)
      final editionId = bibkey;

      // Get details object (jscmd=details puts EVERYTHING here)
      final details = data['details'] as Map<String, dynamic>?;
      if (details != null) {
        LoggingService.error('DEBUG: Keys in details: ${details.keys.toList()}');
      } else {
        LoggingService.error('DEBUG: No details object found');
        return null;
      }

      // Extract work ID from works field (inside details in jscmd=details)
      String workId = '';
      if (details['works'] != null && details['works'] is List) {
        final works = details['works'] as List;
        if (works.isNotEmpty && works[0] is Map) {
          final workData = works[0] as Map;
          if (workData['key'] != null) {
            final key = workData['key'] as String;
            workId = key.replaceFirst('/works/', '');
            LoggingService.error('DEBUG: Extracted work ID: $workId');
          }
        }
      }

      // Extract title (inside details in jscmd=details)
      final title = details['title'] as String? ?? 'Unknown Title';
      LoggingService.error('DEBUG: Title: $title');

      // Extract authors (inside details in jscmd=details)
      List<String> authors = [];
      if (details['authors'] != null && details['authors'] is List) {
        authors = (details['authors'] as List)
            .where((a) => a is Map && a['name'] != null)
            .map((a) => (a as Map)['name'] as String)
            .toList();
        LoggingService.error('DEBUG: Authors: $authors');
      } else {
        LoggingService.error('DEBUG: No authors found, details[\'authors\']: ${details['authors']}');
      }

      // Extract cover - in jscmd=details, covers is an array of IDs under 'details'
      int? coverImageId;
      String? coverEditionId;
      if (details['covers'] != null && details['covers'] is List) {
        final covers = details['covers'] as List;
        if (covers.isNotEmpty) {
          coverImageId = covers[0] as int?;
        }
      }

      // Extract publish date (under details in jscmd=details)
      final publishDate = details['publish_date'] as String?;

      // Extract publishers (under details in jscmd=details)
      String? publisher;
      if (details['publishers'] != null && details['publishers'] is List) {
        final publishers = details['publishers'] as List;
        if (publishers.isNotEmpty) {
          // In jscmd=details, publishers is just an array of strings
          publisher = publishers[0] as String?;
        }
      }

      // Extract page count (under details in jscmd=details)
      final numberOfPages = details['number_of_pages'] as int?;

      // Extract ISBNs (under details in jscmd=details)
      List<String> isbn = [];
      if (details['identifiers'] != null && details['identifiers'] is Map) {
        final identifiers = details['identifiers'] as Map;
        if (identifiers['isbn_10'] != null && identifiers['isbn_10'] is List) {
          isbn.addAll((identifiers['isbn_10'] as List).map((i) => i.toString()));
        }
        if (identifiers['isbn_13'] != null && identifiers['isbn_13'] is List) {
          isbn.addAll((identifiers['isbn_13'] as List).map((i) => i.toString()));
        }
      }

      // Extract description - check multiple possible locations
      String? description;
      // Try subtitle first (common in jscmd=details)
      if (details['subtitle'] != null) {
        description = details['subtitle'] as String?;
      }
      // Try excerpts
      if (description == null && details['excerpts'] != null && details['excerpts'] is List) {
        final excerpts = details['excerpts'] as List;
        if (excerpts.isNotEmpty && excerpts[0] is Map) {
          description = (excerpts[0] as Map)['text'] as String?;
        }
      }

      return BookModel(
        editionId: editionId,
        workId: workId,
        title: title,
        authors: authors,
        coverImageId: coverImageId,
        coverEditionId: coverEditionId ?? editionId,
        publishDate: publishDate,
        publisher: publisher,
        numberOfPages: numberOfPages,
        isbn: isbn,
        description: description,
      );
    } catch (e) {
      LoggingService.error('Error converting Books API data: $e');
      return null;
    }
  }

  /// Batch fetch authors from list seeds
  ///
  /// Fetches authors in parallel batches to avoid rate limiting
  Future<List<AuthorModel>> fetchAuthorsFromSeeds(List<ListSeedModel> authorSeeds) async {
    if (authorSeeds.isEmpty) return [];

    final authors = <AuthorModel>[];

    // Fetch authors in parallel batches to be respectful of rate limits
    const concurrency = 5; // Fetch 5 at a time
    for (var i = 0; i < authorSeeds.length; i += concurrency) {
      final batch = authorSeeds.skip(i).take(concurrency).toList();
      final futures = batch.map((seed) => _fetchSingleAuthor(seed.url));

      try {
        final results = await Future.wait(futures);
        authors.addAll(results.whereType<AuthorModel>());
      } catch (e) {
        LoggingService.error('Error fetching author batch: $e');
        // Continue with next batch
      }
    }

    return authors;
  }

  /// Fetch a single author from the authors API
  /// Handles redirects by following the location to the actual author
  Future<AuthorModel?> _fetchSingleAuthor(String authorUrl) async {
    try {
      final url = '${ApiConstants.openLibraryBaseUrl}$authorUrl.json';
      final response = await dioClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }

        // Check if this is a redirect response
        final type = data['type'];
        if (type is Map && type['key'] == '/type/redirect') {
          // Extract the redirect location (e.g., "/authors/OL123456A")
          final location = data['location'] as String?;
          if (location != null && location.startsWith('/authors/')) {
            LoggingService.error('DEBUG: Author $authorUrl redirects to $location');

            // Fetch the actual author data by recursively calling this method
            return await _fetchSingleAuthor(location);
          }
        }

        return AuthorModel.fromJson(data);
      }
    } catch (e) {
      LoggingService.error('Error fetching author $authorUrl: $e');
    }
    return null;
  }

  /// Fetch user's current book loans from OpenLibrary API
  ///
  /// Returns map of edition ID to loan data
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<Map<String, dynamic>> fetchUserLoans() async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      final response = await dioClient.get(
        '${ApiConstants.openLibraryBaseUrl}/account/loans.json',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      // Parse response
      Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        data = response.data as Map<String, dynamic>;
      }

      // Transform loans into a map keyed by edition ID
      final loansMap = <String, dynamic>{};
      if (data.containsKey('loans')) {
        final loans = data['loans'] as List;
        for (final loan in loans) {
          final bookId = (loan['book'] as String)
              .replaceAll('/books/', '');
          loansMap[bookId] = loan;
        }
      }

      return loansMap;
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error fetching loans');
    } catch (e) {
      throw ServerException('Failed to fetch loans: $e');
    }
  }

  /// Add a book to a list
  ///
  /// [listUrl] - The list URL (e.g., "/people/username/lists/OL123L")
  /// [workId] - The work ID to add (e.g., "OL123W")
  /// [editionId] - Optional edition ID (e.g., "OL123M")
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<void> addBookToList({
    required String listUrl,
    required String workId,
    String? editionId,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Determine seed to add (prefer edition if available, otherwise work)
      final seed = editionId != null && editionId.isNotEmpty
          ? '/books/$editionId'
          : '/works/$workId';

      // API endpoint: POST /people/{username}/lists/{list_id}/seeds
      final url = '${ApiConstants.openLibraryBaseUrl}$listUrl/seeds';

      LoggingService.error('DEBUG: Adding book to list: POST $url with seed $seed');

      final response = await dioClient.post(
        url,
        data: {
          'add': [
            {'key': seed}
          ]
        },
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException('Failed to add book to list: ${response.statusCode}');
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error adding book to list');
    } catch (e) {
      throw ServerException('Failed to add book to list: $e');
    }
  }

  /// Remove a book from a list
  ///
  /// [listUrl] - The list URL (e.g., "/people/username/lists/OL123L")
  /// [workId] - The work ID to remove (e.g., "OL123W")
  /// [editionId] - Optional edition ID (e.g., "OL123M")
  /// Throws [ServerException], [NetworkException], or [AuthException]
  Future<void> removeBookFromList({
    required String listUrl,
    required String workId,
    String? editionId,
  }) async {
    try {
      // Ensure cookies are loaded from storage
      await authDataSource.ensureCookiesLoaded();

      final cookieHeader = authDataSource.cookieHeader;
      if (cookieHeader == null || cookieHeader.isEmpty) {
        throw const AuthException('Not logged in');
      }

      // Determine seed to remove (prefer edition if available, otherwise work)
      final seed = editionId != null && editionId.isNotEmpty
          ? '/books/$editionId'
          : '/works/$workId';

      // API endpoint: POST /people/{username}/lists/{list_id}/seeds
      final url = '${ApiConstants.openLibraryBaseUrl}$listUrl/seeds';

      LoggingService.error('DEBUG: Removing book from list: POST $url with seed $seed');

      final response = await dioClient.post(
        url,
        data: {
          'remove': [
            {'key': seed}
          ]
        },
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to remove book from list: ${response.statusCode}');
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Unauthorized - please login again');
      }
      throw NetworkException(e.message ?? 'Network error removing book from list');
    } catch (e) {
      throw ServerException('Failed to remove book from list: $e');
    }
  }
}
