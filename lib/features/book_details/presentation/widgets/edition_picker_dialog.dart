import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_header.dart';
import '../../domain/entities/edition.dart';

/// Dialog for selecting a book edition
class EditionPickerDialog extends StatefulWidget {
  final Future<List<Edition>> editionsFuture;
  final String currentEditionId;
  final String? currentShelfKey;
  final Function(String editionId) onEditionSelected;

  const EditionPickerDialog({
    super.key,
    required this.editionsFuture,
    required this.currentEditionId,
    this.currentShelfKey,
    required this.onEditionSelected,
  });

  @override
  State<EditionPickerDialog> createState() => _EditionPickerDialogState();
}

class _EditionPickerDialogState extends State<EditionPickerDialog> {
  String? _changingToEditionId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with explanation
            const DialogHeader(
              title: 'Change Edition',
              subtitle: 'Open Library books are often available in multiple editions. '
                  'If more than one is available, you can change the edition that you have on your shelf (highlighted below).',
            ),

            // Edition list with loading state
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              alignment: Alignment.topCenter,
              curve: Curves.easeInOut,
              child: FutureBuilder<List<Edition>>(
                future: widget.editionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildNoEditionsMessage();
                  } else {
                    final editions = snapshot.data!;
                    return editions.length == 1
                        ? _buildSingleEditionMessage()
                        : _buildEditionList(editions);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40.0),
      child: Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.tertiary),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        'Failed to load editions: $error',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildNoEditionsMessage() {
    return Container(
      width: 360,
      margin: const EdgeInsets.all(20.0),
      child: const Text(
        'No readable editions available',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEditionList(List<Edition> editions) {
    // Sort editions by publication date ascending (oldest first)
    final sortedEditions = List<Edition>.from(editions)..sort((a, b) {
      // Handle null publish dates - put them at the end
      if (a.publishDate == null && b.publishDate == null) return 0;
      if (a.publishDate == null) return 1;
      if (b.publishDate == null) return -1;

      // Try to parse as integers (for years like "2020", "2019")
      final aYear = int.tryParse(a.publishDate!);
      final bYear = int.tryParse(b.publishDate!);

      if (aYear != null && bYear != null) {
        return aYear.compareTo(bYear);
      }

      // Fallback to string comparison for dates like "January 1, 2020"
      return a.publishDate!.compareTo(b.publishDate!);
    });

    return ListView.separated(
      shrinkWrap: true,
      itemCount: sortedEditions.length,
      itemBuilder: (context, index) {
        final edition = sortedEditions[index];
        final isSelected = edition.editionId == widget.currentEditionId;
        final isChanging = _changingToEditionId == edition.editionId;

        return Container(
          color: isSelected
              ? Theme.of(context).colorScheme.surfaceContainer
              : null,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(25, 5.0, 15, 5),
            leading: Stack(
              children: [
                // Cover image with opacity when changing
                Opacity(
                  opacity: isChanging ? 0.25 : 1.0,
                  child: _buildCoverImage(context, edition),
                ),
                // Loading indicator when changing
                if (isChanging)
                  const Positioned(
                    left: 5.0,
                    top: 5.0,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            title: Text(
              edition.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              edition.displayInfo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  )
                : null,
            onTap: isChanging
                ? null
                : () async {
                    setState(() {
                      _changingToEditionId = edition.editionId;
                    });

                    // Call the callback and wait for it to complete
                    await widget.onEditionSelected(edition.editionId);

                    // Close the dialog
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
        );
      },
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        color: Colors.white38,
      ),
    );
  }

  Widget _buildSingleEditionMessage() {
    return Container(
      width: 360,
      margin: const EdgeInsets.all(20.0),
      child: const Text(
        '(Only one e-book edition of this work is available)',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, Edition edition) {
    final coverUrl = edition.coverImageUrl;

    // Build the placeholder widget
    final placeholderWidget = Container(
      width: 40,
      height: 60,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.book,
        color: Theme.of(context).primaryColor,
      ),
    );

    return SizedBox(
      width: 40,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          width: 40,
          height: 60,
          memCacheHeight: 240,       // Increased from 120
          memCacheWidth: 160,        // Increased from 80
          maxHeightDiskCache: 480,   // Added disk caching
          cacheKey: coverUrl,        // Added custom cache key
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => placeholderWidget,
          errorWidget: (context, url, error) => placeholderWidget,
          // Web-specific optimizations

        ),
      ),
    );
  }
}
