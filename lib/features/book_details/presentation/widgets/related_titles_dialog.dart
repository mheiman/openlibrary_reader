import 'package:flutter/material.dart';

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
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 500,
          maxWidth: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),

            // Related books list
            Flexible(
              child: FutureBuilder<List<Book>>(
                future: relatedBooksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(1.0, 1.0),
            blurRadius: 5.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Related Titles',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close),
              color: Colors.white,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40.0),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching for related books...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        'Failed to load related titles: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
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
