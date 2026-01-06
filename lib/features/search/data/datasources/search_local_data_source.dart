import 'package:injectable/injectable.dart';

import '../../../../core/storage/preferences_service.dart';

/// Local data source for search history
@lazySingleton
class SearchLocalDataSource {
  final PreferencesService preferencesService;

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 20;

  SearchLocalDataSource(this.preferencesService);

  /// Get recent search queries
  Future<List<String>> getRecentSearches() async {
    return preferencesService.getStringList(_recentSearchesKey) ?? [];
  }

  /// Save search query to history
  ///
  /// Adds query to the beginning of the list and removes duplicates
  Future<void> saveSearchQuery({required String query}) async {
    // Get current searches
    final searches = await getRecentSearches();

    // Remove query if it already exists
    searches.remove(query);

    // Add to beginning
    searches.insert(0, query);

    // Limit to max count
    if (searches.length > _maxRecentSearches) {
      searches.removeRange(_maxRecentSearches, searches.length);
    }

    // Save updated list
    await preferencesService.setStringList(_recentSearchesKey, searches);
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    await preferencesService.remove(_recentSearchesKey);
  }
}
