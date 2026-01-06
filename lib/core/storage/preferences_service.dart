import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error/exceptions.dart';

@lazySingleton
class PreferencesService {
  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw CacheException('Failed to initialize SharedPreferences: $e');
    }
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw CacheException('SharedPreferences not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// Get string value
  String? getString(String key) {
    try {
      return prefs.getString(key);
    } catch (e) {
      throw CacheException('Failed to get string: $e');
    }
  }

  /// Set string value
  Future<bool> setString(String key, String value) async {
    try {
      return await prefs.setString(key, value);
    } catch (e) {
      throw CacheException('Failed to set string: $e');
    }
  }

  /// Get int value
  int? getInt(String key) {
    try {
      return prefs.getInt(key);
    } catch (e) {
      throw CacheException('Failed to get int: $e');
    }
  }

  /// Set int value
  Future<bool> setInt(String key, int value) async {
    try {
      return await prefs.setInt(key, value);
    } catch (e) {
      throw CacheException('Failed to set int: $e');
    }
  }

  /// Get bool value
  bool? getBool(String key) {
    try {
      return prefs.getBool(key);
    } catch (e) {
      throw CacheException('Failed to get bool: $e');
    }
  }

  /// Set bool value
  Future<bool> setBool(String key, bool value) async {
    try {
      return await prefs.setBool(key, value);
    } catch (e) {
      throw CacheException('Failed to set bool: $e');
    }
  }

  /// Get double value
  double? getDouble(String key) {
    try {
      return prefs.getDouble(key);
    } catch (e) {
      throw CacheException('Failed to get double: $e');
    }
  }

  /// Set double value
  Future<bool> setDouble(String key, double value) async {
    try {
      return await prefs.setDouble(key, value);
    } catch (e) {
      throw CacheException('Failed to set double: $e');
    }
  }

  /// Get string list value
  List<String>? getStringList(String key) {
    try {
      return prefs.getStringList(key);
    } catch (e) {
      throw CacheException('Failed to get string list: $e');
    }
  }

  /// Set string list value
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      return await prefs.setStringList(key, value);
    } catch (e) {
      throw CacheException('Failed to set string list: $e');
    }
  }

  /// Remove a key
  Future<bool> remove(String key) async {
    try {
      return await prefs.remove(key);
    } catch (e) {
      throw CacheException('Failed to remove key: $e');
    }
  }

  /// Clear all preferences
  Future<bool> clear() async {
    try {
      return await prefs.clear();
    } catch (e) {
      throw CacheException('Failed to clear preferences: $e');
    }
  }

  /// Check if key exists
  bool containsKey(String key) {
    try {
      return prefs.containsKey(key);
    } catch (e) {
      throw CacheException('Failed to check key: $e');
    }
  }

  /// Get all keys
  Set<String> getKeys() {
    try {
      return prefs.getKeys();
    } catch (e) {
      throw CacheException('Failed to get keys: $e');
    }
  }
}
