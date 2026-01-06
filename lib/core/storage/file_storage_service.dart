import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../error/exceptions.dart';

@lazySingleton
class FileStorageService {
  /// Get the application documents directory
  Future<Directory> get _documentsDirectory async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      throw CacheException('Failed to get documents directory: $e');
    }
  }

  /// Get file path for a given filename
  Future<String> getFilePath(String filename) async {
    final dir = await _documentsDirectory;
    return '${dir.path}/$filename';
  }

  /// Read JSON from file
  Future<Map<String, dynamic>?> readJson(String filename) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      if (!await file.exists()) {
        return null;
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return null;
      }

      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      throw CacheException('Failed to read JSON from file: $e');
    }
  }

  /// Write JSON to file
  Future<void> writeJson(String filename, Map<String, dynamic> data) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      final jsonString = json.encode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      throw CacheException('Failed to write JSON to file: $e');
    }
  }

  /// Read string from file
  Future<String?> readString(String filename) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      if (!await file.exists()) {
        return null;
      }

      return await file.readAsString();
    } catch (e) {
      throw CacheException('Failed to read string from file: $e');
    }
  }

  /// Write string to file
  Future<void> writeString(String filename, String data) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      await file.writeAsString(data);
    } catch (e) {
      throw CacheException('Failed to write string to file: $e');
    }
  }

  /// Delete file
  Future<void> deleteFile(String filename) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw CacheException('Failed to delete file: $e');
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filename) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);
      return await file.exists();
    } catch (e) {
      throw CacheException('Failed to check file existence: $e');
    }
  }

  /// Get file last modified date
  Future<DateTime?> getFileLastModified(String filename) async {
    try {
      final path = await getFilePath(filename);
      final file = File(path);

      if (!await file.exists()) {
        return null;
      }

      return await file.lastModified();
    } catch (e) {
      throw CacheException('Failed to get file last modified: $e');
    }
  }

  /// Check if file is stale (older than specified hours)
  Future<bool> isFileStale(String filename, int validityHours) async {
    try {
      final lastModified = await getFileLastModified(filename);
      if (lastModified == null) {
        return true;
      }

      final now = DateTime.now();
      final difference = now.difference(lastModified);
      return difference.inHours >= validityHours;
    } catch (e) {
      throw CacheException('Failed to check if file is stale: $e');
    }
  }

  /// List all files in the documents directory
  Future<List<String>> listFiles() async {
    try {
      final dir = await _documentsDirectory;
      final entities = dir.listSync();

      return entities
          .whereType<File>()
          .map((file) => file.path.split('/').last)
          .toList();
    } catch (e) {
      throw CacheException('Failed to list files: $e');
    }
  }
}
