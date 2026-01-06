import 'package:flutter/material.dart';
import '../../../shelves/presentation/widgets/generic_sort_dialog.dart';

/// Sort order options for search results
enum SearchSortOrder {
  title,
  author,
  datePublished,
}

/// Dialog for sorting search results
class SearchSortDialog extends StatelessWidget {
  final SearchSortOrder currentSortOrder;
  final bool currentAscending;
  final Function(SearchSortOrder sortOrder, bool ascending) onSortChanged;

  const SearchSortDialog({
    super.key,
    required this.currentSortOrder,
    required this.currentAscending,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Create sort options
    final sortOptions = [
      GenericSortOption<SearchSortOrder>(
        isSelected: currentSortOrder == SearchSortOrder.datePublished,
        sortValue: SearchSortOrder.datePublished,
        description: 'Publication date',
      ),
      GenericSortOption<SearchSortOrder>(
        isSelected: currentSortOrder == SearchSortOrder.author,
        sortValue: SearchSortOrder.author,
        description: 'Author',
      ),
      GenericSortOption<SearchSortOrder>(
        isSelected: currentSortOrder == SearchSortOrder.title,
        sortValue: SearchSortOrder.title,
        description: 'Title',
      ),
    ];

    return GenericSortDialog<SearchSortOrder>(
      title: 'Sort results',
      sortOptions: sortOptions,
      initialAscending: currentAscending,
      onSortChanged: onSortChanged,
    );
  }
}
