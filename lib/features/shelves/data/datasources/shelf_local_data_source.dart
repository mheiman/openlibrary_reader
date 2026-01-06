import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/storage/file_storage_service.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../domain/entities/shelf.dart';
import '../models/author_model.dart';
import '../models/book_model.dart';
import '../models/shelf_model.dart';

/// Local data source for shelf caching
@lazySingleton
class ShelfLocalDataSource {
  final FileStorageService fileStorage;
  final PreferencesService preferencesService;

  ShelfLocalDataSource(this.fileStorage, this.preferencesService);

  /// Get cached shelves from local storage
  ///
  /// Returns list of [ShelfModel] or throws [CacheException]
  Future<List<ShelfModel>> getCachedShelves() async {
    try {
      final data = await fileStorage.readJson(ApiConstants.shelfDataFileName);

      if (data == null) {
        throw const CacheException('No cached shelf data found');
      }

      final List<ShelfModel> shelves = [];

      // Data is stored as: { 'shelf-key': { ... shelf data ... } }
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          try {
            final shelfModel = ShelfModel.fromJson(value);
            shelves.add(shelfModel);
          } catch (e) {
            LoggingService.error('Error parsing cached shelf $key: $e');
          }
        }
      });

      return shelves;
    } catch (e) {
      throw CacheException('Failed to get cached shelves: $e');
    }
  }

  /// Cache shelves to local storage
  ///
  /// Throws [CacheException] on failure
  Future<void> cacheShelves(List<ShelfModel> shelves) async {
    try {
      // Convert list to map: { 'shelf-key': { ... shelf data ... } }
      final Map<String, dynamic> data = {};

      for (var shelf in shelves) {
        data[shelf.key] = shelf.toJson();
      }

      await fileStorage.writeJson(ApiConstants.shelfDataFileName, data);
    } catch (e) {
      throw CacheException('Failed to cache shelves: $e');
    }
  }

  /// Get cached shelf by key
  ///
  /// Returns [ShelfModel] or throws [CacheException]
  Future<ShelfModel> getCachedShelf(String shelfKey) async {
    try {
      final data = await fileStorage.readJson(ApiConstants.shelfDataFileName);

      if (data == null || !data.containsKey(shelfKey)) {
        throw CacheException('No cached data for shelf: $shelfKey');
      }

      return ShelfModel.fromJson(data[shelfKey] as Map<String, dynamic>);
    } catch (e) {
      throw CacheException('Failed to get cached shelf: $e');
    }
  }

  /// Update cached shelf
  ///
  /// Throws [CacheException] on failure
  Future<void> updateCachedShelf(ShelfModel shelf) async {
    try {
      // Get existing data
      final data = await fileStorage.readJson(ApiConstants.shelfDataFileName) ?? {};

      // Update the specific shelf
      data[shelf.key] = shelf.toJson();

      // Write back
      await fileStorage.writeJson(ApiConstants.shelfDataFileName, data);
    } catch (e) {
      throw CacheException('Failed to update cached shelf: $e');
    }
  }

  /// Clear all cached shelf data
  ///
  /// Throws [CacheException] on failure
  Future<void> clearCache() async {
    try {
      // Clear shelf data
      await fileStorage.deleteFile(ApiConstants.shelfDataFileName);

      // Clear all list caches
      await clearAllListCaches();
    } catch (e) {
      throw CacheException('Failed to clear cache: $e');
    }
  }

  /// Get configured shelf keys from preferences
  ///
  /// Returns list of shelf keys or default list
  Future<List<String>> getConfiguredShelfKeys() async {
    try {
      final keys = preferencesService.getStringList(ApiConstants.prefShelfVisibility);
      if (keys != null && keys.isNotEmpty) {
        return keys;
      }

      // Return default shelves
      return ['want-to-read', 'currently-reading', 'already-read'];
    } catch (e) {
      // Return default on error
      return ['want-to-read', 'currently-reading', 'already-read'];
    }
  }

  /// Update configured shelf keys in preferences
  ///
  /// Throws [CacheException] on failure
  Future<void> updateConfiguredShelfKeys(List<String> keys) async {
    try {
      await preferencesService.setStringList(ApiConstants.prefShelfVisibility, keys);
    } catch (e) {
      throw CacheException('Failed to update shelf keys: $e');
    }
  }

  /// Get shelf sort order from preferences
  ///
  /// Returns [ShelfSortOrder] or default
  Future<ShelfSortOrder> getShelfSortOrder(String shelfKey) async {
    try {
      final sortKey = '${ApiConstants.prefSortOrder}_$shelfKey';
      final sortIndex = preferencesService.getInt(sortKey);

      if (sortIndex != null && sortIndex < ShelfSortOrder.values.length) {
        return ShelfSortOrder.values[sortIndex];
      }

      return ShelfSortOrder.dateAdded;
    } catch (e) {
      return ShelfSortOrder.dateAdded;
    }
  }

  /// Get shelf sort direction from preferences
  ///
  /// Returns true for ascending, false for descending
  Future<bool> getShelfSortAscending(String shelfKey) async {
    try {
      final directionKey = '${ApiConstants.prefSortOrder}_${shelfKey}_asc';
      final ascending = preferencesService.getBool(directionKey);
      return ascending ?? true; // Default to ascending
    } catch (e) {
      return true;
    }
  }

  /// Update shelf sort order and direction in preferences
  ///
  /// Throws [CacheException] on failure
  Future<void> updateShelfSortOrder(
    String shelfKey,
    ShelfSortOrder sortOrder,
    bool ascending,
  ) async {
    try {
      final sortKey = '${ApiConstants.prefSortOrder}_$shelfKey';
      final directionKey = '${ApiConstants.prefSortOrder}_${shelfKey}_asc';

      await preferencesService.setInt(sortKey, sortOrder.index);
      await preferencesService.setBool(directionKey, ascending);
    } catch (e) {
      throw CacheException('Failed to update sort order: $e');
    }
  }

  /// Get selected list URL from preferences
  ///
  /// Returns saved list URL or null
  Future<String?> getSelectedListUrl() async {
    try {
      return preferencesService.getString(ApiConstants.prefSelectedList);
    } catch (e) {
      return null;
    }
  }

  /// Update selected list URL in preferences
  ///
  /// Pass null to clear selection
  /// Throws [CacheException] on failure
  Future<void> updateSelectedListUrl(String? listUrl) async {
    try {
      if (listUrl == null) {
        await preferencesService.remove(ApiConstants.prefSelectedList);
      } else {
        await preferencesService.setString(ApiConstants.prefSelectedList, listUrl);
      }
    } catch (e) {
      throw CacheException('Failed to update selected list: $e');
    }
  }

  /// Get cached list items (books and authors)
  ///
  /// Returns (books, authors, lastSynced) tuple or null if not cached
  Future<(List<BookModel>, List<AuthorModel>, DateTime)?> getCachedListItems(String listUrl) async {
    try {
      // Sanitize list URL for use as filename
      final filename = 'list_${_sanitizeListUrl(listUrl)}.json';
      final data = await fileStorage.readJson(filename);

      if (data == null) {
        return null;
      }

      // Extract timestamp
      final lastSyncedStr = data['lastSynced'] as String?;
      if (lastSyncedStr == null) {
        return null;
      }

      final lastSynced = DateTime.parse(lastSyncedStr);

      // Extract books
      final booksData = data['books'] as List?;
      if (booksData == null) {
        return null;
      }

      final books = booksData
          .map((bookJson) => BookModel.fromJson(bookJson as Map<String, dynamic>))
          .toList();

      // Extract authors (may not exist in older cache entries)
      final authorsData = data['authors'] as List?;
      final authors = authorsData
          ?.map((authorJson) => AuthorModel.fromCachedJson(authorJson as Map<String, dynamic>))
          .toList() ?? [];

      return (books, authors, lastSynced);
    } catch (e) {
      return null;
    }
  }

  /// Get cached list books (deprecated - use getCachedListItems)
  ///
  /// Returns (books, lastSynced) tuple or null if not cached
  @Deprecated('Use getCachedListItems instead')
  Future<(List<BookModel>, DateTime)?> getCachedListBooks(String listUrl) async {
    final result = await getCachedListItems(listUrl);
    if (result == null) return null;
    final (books, _, lastSynced) = result;
    return (books, lastSynced);
  }

  /// Cache list items (books and authors)
  ///
  /// Throws [CacheException] on failure
  Future<void> cacheListItems(
    String listUrl,
    List<BookModel> books,
    List<AuthorModel> authors,
  ) async {
    try {
      // Sanitize list URL for use as filename
      final filename = 'list_${_sanitizeListUrl(listUrl)}.json';

      final data = {
        'lastSynced': DateTime.now().toIso8601String(),
        'books': books.map((book) => book.toJson()).toList(),
        'authors': authors.map((author) => author.toJson()).toList(),
      };

      await fileStorage.writeJson(filename, data);
    } catch (e) {
      throw CacheException('Failed to cache list items: $e');
    }
  }

  /// Cache list books (deprecated - use cacheListItems)
  ///
  /// Throws [CacheException] on failure
  @Deprecated('Use cacheListItems instead')
  Future<void> cacheListBooks(String listUrl, List<BookModel> books) async {
    await cacheListItems(listUrl, books, []);
  }

  /// Clear cached list books for a specific list
  ///
  /// Throws [CacheException] on failure
  Future<void> clearListContents(String listUrl) async {
    try {
      final filename = 'list_${_sanitizeListUrl(listUrl)}.json';
      await fileStorage.deleteFile(filename);
    } catch (e) {
      throw CacheException('Failed to clear list contents: $e');
    }
  }

  /// Clear all cached list books
  ///
  /// Called during logout to clear all list data
  Future<void> clearAllListCaches() async {
    try {
      // Get all files in storage directory
      final files = await fileStorage.listFiles();

      // Delete all files that start with 'list_'
      for (final file in files) {
        if (file.startsWith('list_')) {
          try {
            await fileStorage.deleteFile(file);
          } catch (e) {
            // Continue deleting other files even if one fails
            LoggingService.warning('Failed to delete list cache file $file: $e');
          }
        }
      }
    } catch (e) {
      throw CacheException('Failed to clear all list caches: $e');
    }
  }

  /// Sanitize list URL for use as filename
  String _sanitizeListUrl(String listUrl) {
    // Remove leading slash and replace other slashes with underscores
    return listUrl.replaceAll('/', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
