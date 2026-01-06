import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with explanation
              _buildHeader(context),

              // Edition list with loading state
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.topCenter,
                curve: Curves.easeInOut,
                child: SizedBox(
                  width: 400,
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
              ),
            ],
          ),

          // Close button
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close),
              color: Colors.white54,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
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
      width: 400,
      padding: const EdgeInsets.all(20.0),
      child: const Column(
        children: [
          Text(
            'Change Edition',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          SizedBox(height: 15),
          Text(
            'Open Library books are often available in multiple editions. '
            'If more than one is available, you can change the edition that you have on your shelf (highlighted below).',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40.0),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        'Failed to load editions: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
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
    return ListView.separated(
      shrinkWrap: true,
      itemCount: editions.length,
      itemBuilder: (context, index) {
        final edition = editions[index];
        final isSelected = edition.editionId == widget.currentEditionId;
        final isChanging = _changingToEditionId == edition.editionId;

        return Container(
          color: isSelected
              ? Theme.of(context).highlightColor.withValues(alpha: 0.3)
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
