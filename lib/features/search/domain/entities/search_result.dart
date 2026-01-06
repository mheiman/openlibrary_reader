import 'package:equatable/equatable.dart';

/// Search result containing a list of works
class SearchResult extends Equatable {
  final List<WorkSearchItem> works;
  final int totalResults;
  final int currentPage;
  final bool hasMore;

  const SearchResult({
    required this.works,
    required this.totalResults,
    this.currentPage = 1,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [works, totalResults, currentPage, hasMore];

  /// Copy with updated fields
  SearchResult copyWith({
    List<WorkSearchItem>? works,
    int? totalResults,
    int? currentPage,
    bool? hasMore,
  }) {
    return SearchResult(
      works: works ?? this.works,
      totalResults: totalResults ?? this.totalResults,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Individual work in search results
class WorkSearchItem extends Equatable {
  final String workId; // OL work ID
  final String title;
  final List<String> authors;
  final List<String> authorKeys;
  final int? firstPublishYear;
  final int? ebookCount;
  final String? coverImageId;
  final String? lendingEdition; // Edition ID that can be borrowed
  final String? availability;
  final List<String> subjects;

  const WorkSearchItem({
    required this.workId,
    required this.title,
    this.authors = const [],
    this.authorKeys = const [],
    this.firstPublishYear,
    this.ebookCount,
    this.coverImageId,
    this.lendingEdition,
    this.availability,
    this.subjects = const [],
  });

  @override
  List<Object?> get props => [
        workId,
        title,
        authors,
        authorKeys,
        firstPublishYear,
        ebookCount,
        coverImageId,
        lendingEdition,
        availability,
        subjects,
      ];

  /// Get cover image URL
  String? get coverImageUrl {
    if (coverImageId != null) {
      return 'https://covers.openlibrary.org/b/id/$coverImageId-M.jpg';
    }
    return null;
  }

  /// Get author names as string
  String get authorsString => authors.join(', ');

  /// Check if book can be borrowed
  bool get canBorrow {
    return lendingEdition != null && lendingEdition!.isNotEmpty;
  }
}
