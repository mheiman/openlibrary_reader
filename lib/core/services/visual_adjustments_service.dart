import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../storage/preferences_service.dart';

/// Service for storing and retrieving visual adjustment settings for books.
///
/// Visual adjustments include settings like brightness, contrast, and other
/// display options that users configure in the book reader. These settings
/// are stored per book and restored when the book is reopened.
@lazySingleton
class VisualAdjustmentsService {
  final PreferencesService _preferencesService;

  static const String _keyPrefix = 'visual_adjustments_';

  VisualAdjustmentsService(this._preferencesService);

  /// Get the storage key for a book's visual adjustments
  String _getKey(String bookId) => '$_keyPrefix$bookId';

  /// Save visual adjustments for a book
  Future<void> saveAdjustments(String bookId, Map<String, dynamic> adjustments) async {
    final key = _getKey(bookId);
    final jsonString = jsonEncode(adjustments);
    await _preferencesService.setString(key, jsonString);
  }

  /// Load visual adjustments for a book
  /// Returns null if no adjustments are saved
  Map<String, dynamic>? loadAdjustments(String bookId) {
    final key = _getKey(bookId);
    final jsonString = _preferencesService.getString(key);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Invalid JSON, remove it
      _preferencesService.remove(key);
      return null;
    }
  }

  /// Remove visual adjustments for a book
  Future<void> removeAdjustments(String bookId) async {
    final key = _getKey(bookId);
    await _preferencesService.remove(key);
  }

  /// Remove visual adjustments for books not in the provided list of book IDs
  /// Call this periodically to clean up orphaned adjustments
  Future<int> cleanupOrphanedAdjustments(Set<String> validBookIds) async {
    final allKeys = _preferencesService.getKeys();
    int removedCount = 0;

    for (final key in allKeys) {
      if (key.startsWith(_keyPrefix)) {
        final bookId = key.substring(_keyPrefix.length);
        if (!validBookIds.contains(bookId)) {
          await _preferencesService.remove(key);
          removedCount++;
        }
      }
    }

    return removedCount;
  }

  /// Get all book IDs that have saved visual adjustments
  Set<String> getSavedBookIds() {
    final allKeys = _preferencesService.getKeys();
    final bookIds = <String>{};

    for (final key in allKeys) {
      if (key.startsWith(_keyPrefix)) {
        bookIds.add(key.substring(_keyPrefix.length));
      }
    }

    return bookIds;
  }
}
