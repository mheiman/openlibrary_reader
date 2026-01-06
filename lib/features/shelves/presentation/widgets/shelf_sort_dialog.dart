import 'package:flutter/material.dart';

import '../../domain/entities/shelf.dart';
import 'generic_sort_dialog.dart';

/// Dialog for sorting shelf books
class ShelfSortDialog extends StatelessWidget {
  final Shelf shelf;
  final Function(ShelfSortOrder sortOrder, bool ascending) onSortChanged;

  const ShelfSortDialog({
    super.key,
    required this.shelf,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Create sort options
    final sortOptions = [
      GenericSortOption<ShelfSortOrder>(
        isSelected: shelf.sortOrder == ShelfSortOrder.dateAdded,
        sortValue: ShelfSortOrder.dateAdded,
        description: 'Date added to shelf',
      ),
      GenericSortOption<ShelfSortOrder>(
        isSelected: shelf.sortOrder == ShelfSortOrder.datePublished,
        sortValue: ShelfSortOrder.datePublished,
        description: 'Publication date',
      ),
      GenericSortOption<ShelfSortOrder>(
        isSelected: shelf.sortOrder == ShelfSortOrder.author,
        sortValue: ShelfSortOrder.author,
        description: 'Author',
      ),
      GenericSortOption<ShelfSortOrder>(
        isSelected: shelf.sortOrder == ShelfSortOrder.title,
        sortValue: ShelfSortOrder.title,
        description: 'Title',
      ),
    ];

    return GenericSortDialog<ShelfSortOrder>(
      title: 'Sort shelf: ${shelf.name}',
      sortOptions: sortOptions,
      initialAscending: shelf.sortAscending,
      onSortChanged: onSortChanged,
    );
  }
}
