import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';

/// Remote data source for reader operations
@lazySingleton
class ReaderRemoteDataSource {
  ReaderRemoteDataSource();

  /// Get reader URL for Archive.org bookreader
  ///
  /// Constructs the borrow URL using the Internet Archive ID
  /// Expected parameter: Internet Archive ID (e.g., 'harrypottersorce00rowl')
  Future<String> getReaderUrl({
    required String bookId, // This is actually the IA ID
  }) async {
    try {
      // The borrow URL pattern for Internet Archive books
      final borrowUrl = '${ApiConstants.openLibraryBaseUrl}/borrow/ia/$bookId?ref=ol';
      return borrowUrl;
    } catch (e) {
      throw ServerException('Failed to construct reader URL: $e');
    }
  }
}
