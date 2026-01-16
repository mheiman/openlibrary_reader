import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_header.dart';

/// Dialog for confirming removal of a book from a list
class RemoveFromListDialog extends StatelessWidget {
  final String bookTitle;
  final String listName;

  const RemoveFromListDialog({
    super.key,
    required this.bookTitle,
    required this.listName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DialogHeader(title: 'Remove from List'),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Remove "$bookTitle" from "$listName"?'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
