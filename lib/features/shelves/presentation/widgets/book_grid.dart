import 'package:flutter/material.dart';

import '../../domain/entities/book.dart';
import 'book_cover.dart';
import 'book_grid_config.dart';

/// Reusable grid widget for displaying books
class BookGrid extends StatelessWidget {
  final List<Book> books;
  final String currentShelfKey;
  final double coverWidth;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final EdgeInsets? padding;
  final bool showChangeEdition;
  final bool showRelatedTitles;
  final bool shrinkWrap;

  const BookGrid({
    super.key,
    required this.books,
    required this.currentShelfKey,
    required this.coverWidth,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.padding,
    this.showChangeEdition = true,
    this.showRelatedTitles = true,
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
          itemCount: books.length,
          itemBuilder: (context, index) {
            return BookCover(
              key: ValueKey(books[index].workId),
              book: books[index],
              currentShelfKey: currentShelfKey,
              coverWidth: coverWidth,
              showChangeEdition: showChangeEdition,
              showRelatedTitles: showRelatedTitles,
            );
          },
        );
  }
}
