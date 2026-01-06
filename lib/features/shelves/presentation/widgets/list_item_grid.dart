import 'package:flutter/material.dart';

import '../../domain/entities/list_display_item.dart';
import 'author_card.dart';
import 'book_cover.dart';
import 'book_grid_config.dart';

/// Reusable grid widget for displaying list items (books, authors, etc.)
class ListItemGrid extends StatelessWidget {
  final List<ListDisplayItem> items;
  final String currentShelfKey;
  final double coverWidth;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final EdgeInsets? padding;
  final bool showChangeEdition;
  final bool showRelatedTitles;
  final bool showRemoveFromList;
  final bool shrinkWrap;

  const ListItemGrid({
    super.key,
    required this.items,
    required this.currentShelfKey,
    required this.coverWidth,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.padding,
    this.showChangeEdition = true,
    this.showRelatedTitles = true,
    this.showRemoveFromList = false,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding ?? BookGridConfig.defaultPadding,
      shrinkWrap: shrinkWrap,
      gridDelegate: BookGridConfig.createGridDelegate(
        coverWidth: coverWidth,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // Use pattern matching to render appropriate widget
        return switch (item) {
          BookDisplayItem(book: final book) => BookCover(
              key: ValueKey(book.workId),
              book: book,
              currentShelfKey: currentShelfKey,
              coverWidth: coverWidth,
              showChangeEdition: showChangeEdition,
              showRelatedTitles: showRelatedTitles,
              showRemoveFromList: showRemoveFromList,
            ),
          AuthorDisplayItem(author: final author) => AuthorCard(
              key: ValueKey(author.id),
              author: author,
              coverWidth: coverWidth,
            ),
        };
      },
    );
  }
}
