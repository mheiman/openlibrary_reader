import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_header.dart';
import '../../domain/entities/book_list.dart';

/// Dialog for selecting a list to add a book to
class AddToListDialog extends StatelessWidget {
  final List<BookList> bookLists;

  const AddToListDialog({
    super.key,
    required this.bookLists,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DialogHeader(title: 'Add to List'),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: bookLists.length,
                itemBuilder: (context, index) {
                  final bookList = bookLists[index];
                  return ListTile(
                    minVerticalPadding: 5,
                    tileColor: Theme.of(context).colorScheme.surfaceContainer,
                    textColor: Theme.of(context).colorScheme.onSurface,
                    title: Text('${bookList.name} (${bookList.seedCount} items)'),
                    onTap: () => Navigator.of(context).pop(bookList.url),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
