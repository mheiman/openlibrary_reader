import 'package:flutter/material.dart';

import '../../domain/entities/book_list.dart';

/// Grid view displaying user's book lists as folder icons
/// Uses a compact layout similar to book covers
class BookListGridView extends StatelessWidget {
  final List<BookList> bookLists;

  // Compact folder width for fitting many lists
  static const double folderWidth = 100.0;
  static const double folderIconSize = 48.0;
  static const double textAreaHeight = 48.0;

  const BookListGridView({
    super.key,
    required this.bookLists,
  });

  @override
  Widget build(BuildContext context) {
    if (bookLists.isEmpty) {
      return const Center(
        child: Text('No lists found'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: folderWidth,
        mainAxisExtent: folderIconSize + textAreaHeight,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: bookLists.length,
      itemBuilder: (context, index) {
        final bookList = bookLists[index];
        return _buildListItem(context, bookList);
      },
    );
  }

  Widget _buildListItem(BuildContext context, BookList bookList) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to list details page
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: folderIconSize,
              width: folderIconSize,
              child: Stack(
                children: [
                  Icon(
                    Icons.folder,
                    size: folderIconSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${bookList.seedCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bookList.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
