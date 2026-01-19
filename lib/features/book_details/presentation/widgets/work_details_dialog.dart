import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../shelves/domain/entities/book.dart';
import '../../../shelves/presentation/state/shelves_notifier.dart';
import '../../../shelves/presentation/state/shelves_state.dart';
import '../../data/datasources/book_details_remote_data_source.dart';

/// Work details dialog (work-focused, not edition-focused)
/// Recreates the old DetailScreen design
class WorkDetailsDialog extends StatefulWidget {
  final Book book;

  const WorkDetailsDialog({
    super.key,
    required this.book,
  });

  @override
  State<WorkDetailsDialog> createState() => _WorkDetailsDialogState();
}

class _WorkDetailsDialogState extends State<WorkDetailsDialog> {
  late final ShelvesNotifier _shelvesNotifier;
  late final BookDetailsRemoteDataSource _bookDetailsDataSource;
  String? _currentShelfKey;
  bool _isMoving = false;
  String? _description;
  bool _isLoadingDescription = false;

  @override
  void initState() {
    super.initState();
    _shelvesNotifier = getIt<ShelvesNotifier>();
    _bookDetailsDataSource = getIt<BookDetailsRemoteDataSource>();
    _findCurrentShelf();
    _fetchWorkDescription();
  }

  void _findCurrentShelf() {
    final state = _shelvesNotifier.state;
    if (state is ShelvesLoaded) {
      for (final shelf in state.shelves) {
        if (shelf.books.any((b) => b.workId == widget.book.workId)) {
          _currentShelfKey = shelf.key;
          break;
        }
      }
    }
  }

  Future<void> _fetchWorkDescription() async {
    // If book already has description, use it
    if (widget.book.description != null && widget.book.description!.isNotEmpty) {
      setState(() {
        _description = widget.book.description;
      });
      return;
    }

    // Otherwise fetch from work API
    if (widget.book.workId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingDescription = true;
    });

    try {
      final workData = await _bookDetailsDataSource.fetchWorkDetails(
        workId: widget.book.workId,
      );

      // Extract description from work data
      String? description;
      if (workData['description'] != null) {
        if (workData['description'] is String) {
          description = workData['description'] as String;
        } else if (workData['description'] is Map && workData['description']['value'] != null) {
          description = workData['description']['value'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _description = description;
          _isLoadingDescription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDescription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main container
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final dialogHeight = screenHeight * 0.8; // 80% of screen height
              
              return Container(
                width: double.infinity,
                height: dialogHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Theme.of(context).colorScheme.surface,
                ),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Header with title and author
                    _buildHeader(context),

                    // Content area with year and description
                    Expanded(
                      child: _buildContent(context),
                    ),

                    // "View at OpenLibrary.org" button and availability
                    _buildFooter(context),

                    // Shelf menu
                    _buildShelfMenu(context),
                  ],
                ),
              );
            },
          ),

          // Cover image (positioned on left, outside container)
          _buildCoverImage(),

          // Close button (top right)
          Positioned(
            right: 15,
            top: -5,
            child: IconButton(
              icon: const Icon(Icons.close),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      color: Theme.of(context).colorScheme.primary,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(130, 30, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.book.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.book.authors.isNotEmpty)
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 5),
                  height: 120, // Fixed height for 3 authors
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: widget.book.authors.map((author) {
                        return Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              color: Theme.of(context).colorScheme.onPrimary,
                              tooltip: 'Search for this author',
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                // Close the dialog
                                Navigator.of(context).pop();

                                // Build search URL with query parameters
                                final queryParams = {
                                  'query': author,
                                  'filter': 'author',
                                };
                                final searchUri = Uri(
                                  path: AppRoutes.search,
                                  queryParameters: queryParams,
                                ).toString();

                                // Use push to maintain navigation stack
                                context.push(searchUri);
                              },
                            ),
                              Flexible(
                                child: Text(
                                  author,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.0,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                      }).toList(),
                    ),
                  ),
                ),
                // Bottom fade gradient - only show if there are more than 3 authors
                if (widget.book.authors.length > 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 25,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 1.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.book.publishDate != null)
            Container(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "First published: ${widget.book.publishDate!}",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          if (_isLoadingDescription)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: CircularProgressIndicator(),
            ),
          if (!_isLoadingDescription && _description != null && _description!.isNotEmpty)
            Flexible(
              child: Markdown(
                data: _fixMarkdownLineBreaks(_description!),
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  blockquoteDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 15),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              final url = 'https://openlibrary.org/works/${widget.book.workId}';
              launchUrl(Uri.parse(url));
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text(
              'View at OpenLibrary.org',
              style: TextStyle(fontSize: 16),
            ),
          ),
          if (widget.book.availability != null)
            Container(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: Text(
                _getAvailabilityText(widget.book.availability!),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShelfMenu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 20),
      alignment: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 275,
            child: ListenableBuilder(
              listenable: _shelvesNotifier,
              builder: (context, _) {
                return _buildShelfButton(context);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 10),
            child: const Text(
              'Added books may have different covers.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelfButton(BuildContext context) {
    final state = _shelvesNotifier.state;

    if (_isMoving) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Moving...'),
      );
    }

    if (_currentShelfKey != null && _currentShelfKey!.isNotEmpty) {
      // Book is on a shelf - show shelf menu
      if (state is ShelvesLoaded) {
        final currentShelf = state.shelves.firstWhere(
          (s) => s.key == _currentShelfKey,
          orElse: () => state.shelves.first,
        );

        return PopupMenuButton<String>(
          child: ElevatedButton.icon(
            style: Theme.of(context).textButtonTheme.style,
            onPressed: null,
            icon: const Icon(Icons.check),
            label: Text('On ${currentShelf.name} shelf'),
          ),
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            for (final shelf in state.shelves) {
              items.add(
                PopupMenuItem<String>(
                  value: shelf.key,
                  enabled: shelf.key != _currentShelfKey,
                  child: Text(shelf.name),
                ),
              );
            }
            items.add(const PopupMenuDivider());
            items.add(
              const PopupMenuItem<String>(
                value: 'remove',
                child: Text('Remove from shelf'),
              ),
            );
            return items;
          },
          onSelected: (value) async {
            setState(() => _isMoving = true);
            if (value == 'remove') {
              await _shelvesNotifier.moveBookToShelf(
                book: widget.book,
                targetShelfKey: '-1',
              );
              setState(() {
                _currentShelfKey = null;
                _isMoving = false;
              });
            } else {
              await _shelvesNotifier.moveBookToShelf(
                book: widget.book,
                targetShelfKey: value,
              );
              setState(() {
                _currentShelfKey = value;
                _isMoving = false;
              });
            }
          },
        );
      }
    }

    // Book is not on any shelf - show add button
    if (state is ShelvesLoaded) {
      return PopupMenuButton<String>(
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add_circle),
          label: const Text('Add to your bookshelf'),
        ),
        itemBuilder: (context) {
          return state.shelves.map((shelf) {
            return PopupMenuItem<String>(
              value: shelf.key,
              child: Text(shelf.name),
            );
          }).toList();
        },
        onSelected: (value) async {
          setState(() => _isMoving = true);
          await _shelvesNotifier.moveBookToShelf(
            book: widget.book,
            targetShelfKey: value,
          );
          setState(() {
            _currentShelfKey = value;
            _isMoving = false;
          });
        },
      );
    }

    return ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.add_circle),
      label: const Text('Add to your bookshelf'),
    );
  }

  Widget _buildCoverImage() {
    final coverUrl = widget.book.coverImageUrl;

    return Positioned(
      left: 0,
      top: -15,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(left: 0),
        alignment: Alignment.topCenter,
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15.0,
              spreadRadius: 1.0,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
        child: coverUrl != null && coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
                // Generous caching settings for book covers
                memCacheWidth: 600,           // Higher quality memory cache
                maxHeightDiskCache: 1000,      // Preserve high-quality images on disk
                cacheKey: coverUrl,            // Custom cache key for reliable caching
                fadeInDuration: const Duration(milliseconds: 300), // Smooth fade-in
                fadeOutDuration: const Duration(milliseconds: 150), // Smooth fade-out
                // Web-specific optimizations

              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 120,
      height: 180,
      color: Colors.grey[300],
      child: const Icon(Icons.book, size: 48),
    );
  }

  String _fixMarkdownLineBreaks(String text) {
    // Convert single newlines to markdown line breaks (two spaces + newline)
    // But preserve double newlines for paragraph breaks
    return text.replaceAllMapped(RegExp(r'\n(?!\n)'), (match) => '  \n');
  }

  String _getAvailabilityText(String availability) {
    switch (availability) {
      case 'borrow_available':
        return 'Available to borrow';
      case 'borrow_unavailable':
        return 'Currently unavailable';
      case 'open':
        return 'Freely available';
      default:
        return availability;
    }
  }
}
