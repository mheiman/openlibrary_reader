import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_header.dart';
import '../../../shelves/domain/entities/book.dart';
import '../../../shelves/presentation/widgets/book_grid.dart';

/// Dialog for displaying related titles
class RelatedTitlesDialog extends StatelessWidget {
  final Future<List<Book>> relatedBooksFuture;
  final double coverWidth;

  const RelatedTitlesDialog({
    super.key,
    required this.relatedBooksFuture,
    this.coverWidth = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const DialogHeader(title: 'Related Titles'),

            // Related books list
            Flexible(
              child: FutureBuilder<List<Book>>(
                future: relatedBooksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState(context);
                  } else if (snapshot.hasError) {
                    return _buildErrorState(context, snapshot.error.toString());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildNoResultsMessage();
                  } else {
                    return _buildBookGrid(snapshot.data!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.tertiary),
          SizedBox(height: 16),
          Text('Querying archive.org for related books...',
          style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface,)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        'Failed to load related titles: $error',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildNoResultsMessage() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: const Text(
        'No related titles found',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return BookGrid(
      books: books,
      currentShelfKey: '', // Empty string since these aren't on a shelf yet
      coverWidth: coverWidth,
      mainAxisSpacing: 16, // Use same spacing as shelf
      showChangeEdition: false,
      showRelatedTitles: false,
      shrinkWrap: true, // Don't expand to fill available space
    );
  }
}
