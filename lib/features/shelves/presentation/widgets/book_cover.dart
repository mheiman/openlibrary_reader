import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/theme/o_l_reader_icons.dart';
import '../../../book_details/data/datasources/book_details_remote_data_source.dart';
import '../../../book_details/domain/entities/edition.dart';
import '../../../book_details/domain/usecases/get_editions.dart';
import '../../../book_details/presentation/widgets/edition_picker_dialog.dart';
import '../../../book_details/presentation/widgets/related_titles_dialog.dart';
import '../../../book_details/presentation/widgets/work_details_dialog.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../../domain/entities/book.dart';
import '../state/shelves_notifier.dart';
import '../state/shelves_state.dart';
import 'add_to_list_dialog.dart';
import 'grid_item_card.dart';
import 'remove_from_list_dialog.dart';

/// Widget to display a book cover
class BookCover extends StatefulWidget {
  final Book book;
  final String currentShelfKey;
  final double coverWidth;
  final bool showChangeEdition;
  final bool showRelatedTitles;
  final bool showRemoveFromList;

  const BookCover({
    super.key,
    required this.book,
    required this.currentShelfKey,
    required this.coverWidth,
    this.showChangeEdition = true,
    this.showRelatedTitles = true,
    this.showRemoveFromList = false,
  });

  @override
  State<BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<BookCover> {
  late final ShelvesNotifier _shelvesNotifier;
  late final SettingsNotifier _settingsNotifier;
  bool _isMoving = false;
  int _currentUrlIndex = 0;
  late List<String> _coverUrls;
  Timer? _loanBadgeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _shelvesNotifier = getIt<ShelvesNotifier>();
    _settingsNotifier = getIt<SettingsNotifier>();
    _coverUrls = widget.book.coverImageUrls;
    _startLoanBadgeRefreshTimer();
  }

  @override
  void dispose() {
    _loanBadgeRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(BookCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset URL index if book changed
    if (oldWidget.book.editionId != widget.book.editionId) {
      _currentUrlIndex = 0;
      _coverUrls = widget.book.coverImageUrls;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridItemCard(
      coverWidth: widget.coverWidth,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      imageBuilder: (context, width, height) {
        return AnimatedOpacity(
          duration: Duration(seconds: _isMoving ? 3 : 0),
          opacity: _isMoving ? 0.3 : 1.0,
          child: _buildCoverImage(context),
        );
      },
      overlayWidgets: [
        // Menu button positioned at top-right
        Positioned(
          top: 3,
          right: 3,
          child: _buildMenuButton(context),
        ),
        // Loan badge positioned at bottom-left
        Positioned(
          bottom: 3,
          left: 3,
          child: _buildLoanBadge(),
        ),
      ],
      textBuilder: (context) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // Author (above title, abbreviate from left to preserve last name)
            if (widget.book.authors.isNotEmpty) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final style =
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                            height: 1.2,
                          );

                  String getAbbreviatedName(String fullName) {
                    final parts = fullName
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    if (parts.isEmpty) return fullName;
                    if (parts.length == 1) return fullName;

                    // Helper to check if text fits
                    bool textFits(String text) {
                      final tp = TextPainter(
                        text: TextSpan(text: text, style: style),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: constraints.maxWidth);
                      return !tp.didExceedMaxLines;
                    }

                    // Check if full name fits
                    if (textFits(fullName)) return fullName;

                    // Progressively abbreviate from left to right
                    final abbreviated = List<String>.from(parts);
                    for (int i = 0; i < parts.length - 1; i++) {
                      // Convert to initial
                      abbreviated[i] = '${parts[i][0]}.';
                      final candidate = abbreviated.join(' ');
                      if (textFits(candidate)) return candidate;
                    }

                    // If still doesn't fit, return the most abbreviated version
                    return abbreviated.join(' ');
                  }

                  return Text(
                    getAbbreviatedName(widget.book.authors.first),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 2),
            ],

            // Book title
            Text(
              widget.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleTap() async {
    try {
      String editionIdToUse = widget.book.editionId;

      // If no edition ID, fetch editions and pick the best one
      if (editionIdToUse.isEmpty) {
        final getEditions = getIt<GetEditions>();
        final result = await getEditions(workId: widget.book.workId);

        await result.fold(
          (failure) {
            throw Exception(
                'Failed to fetch editions: ${failure.message}');
          },
          (editions) async {
            if (editions.isEmpty) {
              throw Exception('No editions available');
            }

            // Pick the best edition: readable/borrowable with oldest publication year
            final readableEditions =
                editions.where((e) => e.canBorrow).toList();

            if (readableEditions.isEmpty) {
              throw Exception('No readable editions available');
            }

            // Sort by publication year (oldest first)
            readableEditions.sort((a, b) {
              final yearA = _parseYear(a.publishDate);
              final yearB = _parseYear(b.publishDate);
              if (yearA == null && yearB == null) return 0;
              if (yearA == null) return 1;
              if (yearB == null) return -1;
              return yearA.compareTo(yearB);
            });

            editionIdToUse = readableEditions.first.editionId;
          },
        );
      }

      // Fetch edition details to get IA ID
      final bookDetailsDataSource =
          getIt<BookDetailsRemoteDataSource>();
      final bookDetails = await bookDetailsDataSource.fetchBookDetails(
        editionId: editionIdToUse,
      );

      // Extract IA ID from book details
      final iaId = bookDetails.ocaid;

      if (!mounted) return;

      // Move to Reading shelf if setting is enabled and book is not already there
      final settingsState = _settingsNotifier.state;
      if (settingsState is SettingsLoaded &&
          settingsState.settings.moveToReading &&
          widget.currentShelfKey != 'currently-reading') {
        // Move book to "currently-reading" shelf
        await _shelvesNotifier.moveBookToShelf(
          book: widget.book,
          targetShelfKey: 'currently-reading',
        );
      }

      if (!mounted) return;

      if (iaId != null && iaId.isNotEmpty) {
        // Navigate to reader with book information for loading overlay
        // ignore: use_build_context_synchronously
        context.push(
          '/reader/$iaId?title=${Uri.encodeComponent(widget.book.title)}'
          '&coverImageId=${widget.book.coverImageId ?? ''}'
          '&coverEditionId=${widget.book.coverEditionId ?? widget.book.editionId}'
          '&workId=${widget.book.workId}',
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This book is not available for reading'),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading book: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _handleDoubleTap() async {
    // Force reload of edition data and clear cached cover
    try {
      // Clear cached cover image
      final coverUrl = widget.book.coverImageUrl;
      final bookTitle = widget.book.title;

      if (coverUrl != null) {
        await CachedNetworkImage.evictFromCache(coverUrl);
      }

      // Trigger single book/shelf refresh to reload data
      await _shelvesNotifier.refreshBook(
        book: widget.book,
        shelfKey: widget.currentShelfKey,
      );

      if (!mounted) return;

      // Show feedback after refresh completes
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Reloaded '),
                TextSpan(
                  text: bookTitle,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reloading book: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Widget _buildCoverImage(BuildContext context) {
    if (_coverUrls.isEmpty) {
      return _buildPlaceholder(context);
    }

    // Get current URL to try
    final coverUrl = _currentUrlIndex < _coverUrls.length
        ? _coverUrls[_currentUrlIndex]
        : null;

    if (coverUrl == null) {
      return _buildPlaceholder(context);
    }

    return Material(
      elevation: 5.0,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(2.0),
      child: _CoverImageLoader(
        key: ValueKey('$coverUrl-$_currentUrlIndex'),
        imageUrl: coverUrl,
        onPlaceholderDetected: _tryNextCoverUrl,
        placeholderBuilder: () => _buildPlaceholder(context),
      ),
    );
  }

  void _tryNextCoverUrl() {
    if (_currentUrlIndex < _coverUrls.length - 1 && mounted) {
      setState(() {
        _currentUrlIndex++;
      });
    }
  }

  void _startLoanBadgeRefreshTimer() {
    _loanBadgeRefreshTimer?.cancel();

    // Get loan minutes to determine refresh interval
    final loanMinutes = _shelvesNotifier.getLoanMinutesRemaining(widget.book.editionId);

    if (loanMinutes <= 0) {
      // No active loan, no need for timer
      return;
    }

    // 30s for <90 min loans, 6 min (360s) for longer loans
    final refreshInterval = loanMinutes < 90
        ? const Duration(seconds: 30)
        : const Duration(seconds: 360);

    _loanBadgeRefreshTimer = Timer.periodic(refreshInterval, (_) {
      if (mounted) {
        setState(() {
          // Just trigger a rebuild to update the badge
        });
      }
    });
  }

  Widget _buildLoanBadge() {
    final loanMinutes = _shelvesNotifier.getLoanMinutesRemaining(widget.book.editionId);

    if (loanMinutes < 1) {
      // No active loan or loan expired
      return const SizedBox.shrink();
    }

    if (loanMinutes < 60) {
      // Short loan - show clock icon with minutes
      return Stack(
        children: [
          const Icon(OLReaderIcons.clock_filled, color: Colors.black87),
          const Icon(OLReaderIcons.clock_filled_outline, color: Colors.white54),
          SizedBox(
            height: 24,
            width: 24,
            child: Align(
              alignment: const Alignment(0.0, 0.3),
              child: Text(
                loanMinutes.toString(),
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    // Long loan - show calendar icon with days
    final days = loanMinutes ~/ (60 * 24);
    return Stack(
      children: [
        const Icon(OLReaderIcons.date, color: Colors.black87),
        const Icon(OLReaderIcons.date_outline, color: Colors.white54),
        SizedBox(
          height: 24,
          width: 24,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              days.toString(),
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2.0),
      ),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.book,
          size: 48,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: _handleMenuAction,
      itemBuilder: (context) => _buildMenuItems(context),
      elevation: 5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Icon(
          Icons.more_horiz_outlined,
          color: Colors.white,
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final state = _shelvesNotifier.state;
    final menuItems = <PopupMenuEntry<String>>[];

    // Determine which shelf this book is currently on (if any)
    // For Related Titles (empty currentShelfKey), look up by work ID
    String actualCurrentShelfKey = widget.currentShelfKey;
    if (actualCurrentShelfKey.isEmpty && state is ShelvesLoaded) {
      // Check if this book (by work ID) exists on any shelf
      for (final shelf in state.shelves) {
        if (shelf.books.any((b) => b.workId == widget.book.workId)) {
          actualCurrentShelfKey = shelf.key;
          break;
        }
      }
    }

    // Add shelf options
    if (state is ShelvesLoaded) {
      for (final shelf in state.shelves) {
        menuItems.add(
          PopupMenuItem<String>(
            value: shelf.key,
            enabled: shelf.key != actualCurrentShelfKey,
            child: Text(shelf.name),
          ),
        );
      }
    }

    // Add Remove option if book is on a shelf
    if (actualCurrentShelfKey.isNotEmpty) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'Remove',
          child: Text('Remove from Shelf'),
        ),
      );
    }

    // Add divider
    menuItems.add(const PopupMenuDivider());

    // Add "Add to list" option if Lists shelf is enabled and has lists
    if (state is ShelvesLoaded && state.bookLists.isNotEmpty) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'Add to List',
          child: Text('Add to List'),
        ),
      );
    }

    // Add "Remove from list" option if enabled
    if (widget.showRemoveFromList && state is ShelvesLoaded && state.selectedListUrl != null) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'Remove from List',
          child: Text('Remove from List'),
        ),
      );
    }

    // Add extra options
    menuItems.add(
      const PopupMenuItem<String>(
        value: 'Book Info',
        child: Text('Book Info'),
      ),
    );

    if (widget.showChangeEdition) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'Change Edition',
          child: Text('Change Edition'),
        ),
      );
    }

    if (widget.showRelatedTitles) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'Related Titles',
          child: Text('Related Titles'),
        ),
      );
    }

    return menuItems;
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'Remove':
        await _removeBook();
        break;
      case 'Book Info':
        _showBookInfo();
        break;
      case 'Change Edition':
        await _showEditionPicker();
        break;
      case 'Related Titles':
        _showRelatedTitles();
        break;
      case 'Add to List':
        await _showAddToListDialog();
        break;
      case 'Remove from List':
        await _removeFromList();
        break;
      default:
        // It's a shelf key - move book to that shelf
        await _moveToShelf(action);
        break;
    }
  }

  Future<void> _moveToShelf(String targetShelfKey) async {
    if (!mounted) return;

    setState(() {
      _isMoving = true;
    });

    // Get target shelf name for feedback message
    String? targetShelfName;
    final state = _shelvesNotifier.state;
    if (state is ShelvesLoaded) {
      targetShelfName = state.shelves
          .firstWhere((shelf) => shelf.key == targetShelfKey,
              orElse: () => state.shelves.first)
          .name;
    }

    await _shelvesNotifier.moveBookToShelf(
      book: widget.book,
      targetShelfKey: targetShelfKey,
    );

    if (mounted) {
      setState(() {
        _isMoving = false;
      });

      // Show feedback snackbar
      if (targetShelfName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.book.title,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  TextSpan(text: ' has been added to $targetShelfName shelf'),
                ],
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _removeBook() async {
    if (!mounted) return;

    setState(() {
      _isMoving = true;
    });

    await _shelvesNotifier.moveBookToShelf(
      book: widget.book,
      targetShelfKey: '-1',
    );

    if (mounted) {
      setState(() {
        _isMoving = false;
      });
    }
  }

  void _showBookInfo() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => WorkDetailsDialog(book: widget.book),
    );
  }

  Future<void> _showEditionPicker() async {
    // Create a future for fetching and filtering editions
    final editionsFuture = _fetchReadableEditions();

    // Show edition picker dialog immediately with the future
    await showDialog(
      context: context,
      builder: (context) => EditionPickerDialog(
        editionsFuture: editionsFuture,
        currentEditionId: widget.book.editionId,
        currentShelfKey: widget.currentShelfKey,
        onEditionSelected: (newEditionId) async {
          // Create a new book with the selected edition
          final updatedBook = Book(
            editionId: newEditionId,
            workId: widget.book.workId,
            title: widget.book.title,
            authors: widget.book.authors,
            coverImageId: widget.book.coverImageId,
            coverEditionId: newEditionId, // Use new edition ID for cover
            addedDate: widget.book.addedDate,
          );

          // Move the book with the new edition to the same shelf
          await _shelvesNotifier.moveBookToShelf(
            book: updatedBook,
            targetShelfKey: widget.currentShelfKey,
          );
        },
      ),
    );
  }

  Future<List<Edition>> _fetchReadableEditions() async {
    final getEditions = getIt<GetEditions>();
    final result = await getEditions(workId: widget.book.workId);

    return result.fold(
      (failure) {
        throw Exception(failure.message);
      },
      (editions) {
        // Filter for readable/borrowable editions only
        return editions.where((e) => e.canBorrow).toList();
      },
    );
  }

  void _showRelatedTitles() {
    if (!mounted) return;

    // Create a future for fetching related titles
    final relatedBooksFuture = _fetchRelatedTitles();

    // Show related titles dialog immediately with the future
    showDialog(
      context: context,
      builder: (context) => RelatedTitlesDialog(
        relatedBooksFuture: relatedBooksFuture,
        coverWidth: widget.coverWidth,
      ),
    );
  }

  Future<List<Book>> _fetchRelatedTitles() async {
    try {
      final bookDetailsDataSource = getIt<BookDetailsRemoteDataSource>();

      // First, get the IA ID for this book if we don't have it
      String? iaId = widget.book.iaId;
      if (iaId == null || iaId.isEmpty) {
        final bookDetails = await bookDetailsDataSource.fetchBookDetails(
          editionId: widget.book.editionId,
        );
        iaId = bookDetails.ocaid;
      }

      if (iaId == null || iaId.isEmpty) {
        return [];
      }

      // Fetch related edition IDs from Archive.org
      final relatedIds = await bookDetailsDataSource.fetchRelatedEditionIds(
        iaId: iaId,
      );

      if (relatedIds.isEmpty) {
        return [];
      }

      // Fetch book details for related editions
      final relatedBooksData = await bookDetailsDataSource.fetchBooksByBibkeys(
        bibkeys: relatedIds,
      );

      // Convert to Book entities and filter out the current work
      final List<Book> relatedBooks = [];
      for (var bookData in relatedBooksData) {
        // Filter out books with the same workID as the current book
        if (bookData.workId != widget.book.workId) {
          relatedBooks.add(Book(
            editionId: bookData.editionId,
            workId: bookData.workId,
            title: bookData.title,
            authors: bookData.authors,
            coverImageId: bookData.coverImageId,
            coverEditionId: bookData.editionId, // Use edition ID for cover
            publishDate: bookData.publishDate,
            publisher: bookData.publisher,
            numberOfPages: bookData.numberOfPages,
            isbn: [...bookData.isbn10, ...bookData.isbn13],
            description: bookData.description,
            iaId: bookData.ocaid,
          ));
        }
      }

      return relatedBooks;
    } catch (e) {
      LoggingService.error('Error fetching related titles: $e');
      rethrow;
    }
  }

  /// Parse year from publication date string
  int? _parseYear(String? publishDate) {
    if (publishDate == null || publishDate.isEmpty) return null;

    // Try to extract a 4-digit year from the string
    final yearMatch = RegExp(r'\b(\d{4})\b').firstMatch(publishDate);
    if (yearMatch != null) {
      return int.tryParse(yearMatch.group(1)!);
    }

    // Try parsing the whole string as a number
    return int.tryParse(publishDate);
  }

  /// Show dialog to select a list to add the book to
  Future<void> _showAddToListDialog() async {
    final state = _shelvesNotifier.state;
    if (state is! ShelvesLoaded || state.bookLists.isEmpty) return;

    final selectedList = await showDialog<String>(
      context: context,
      builder: (context) => AddToListDialog(bookLists: state.bookLists),
    );

    if (selectedList == null) return;

    // Add book to selected list
    try {
      await _shelvesNotifier.addBookToList(
        book: widget.book,
        listUrl: selectedList,
      );

      if (!mounted) return;

      // Find list name for feedback
      final listName = state.bookLists
          .firstWhere((list) => list.url == selectedList)
          .name;

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Added '),
                TextSpan(
                  text: widget.book.title,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ' to $listName'),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding book to list: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Remove book from the currently selected list
  Future<void> _removeFromList() async {
    final state = _shelvesNotifier.state;
    if (state is! ShelvesLoaded || state.selectedListUrl == null) return;

    // Find list name for confirmation
    final listName = state.bookLists
        .firstWhere((list) => list.url == state.selectedListUrl)
        .name;

    // Confirm removal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => RemoveFromListDialog(
        bookTitle: widget.book.title,
        listName: listName,
      ),
    );

    if (confirmed != true) return;

    // Remove book from list
    try {
      await _shelvesNotifier.removeBookFromCurrentList(book: widget.book);

      if (!mounted) return;

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Removed '),
                TextSpan(
                  text: widget.book.title,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ' from $listName'),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing book from list: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Widget that loads a cover image and detects if it's a placeholder
class _CoverImageLoader extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onPlaceholderDetected;
  final Widget Function() placeholderBuilder;

  const _CoverImageLoader({
    super.key,
    required this.imageUrl,
    required this.onPlaceholderDetected,
    required this.placeholderBuilder,
  });

  @override
  State<_CoverImageLoader> createState() => _CoverImageLoaderState();
}

class _CoverImageLoaderState extends State<_CoverImageLoader> {
  bool _isChecking = true;
  bool _isPlaceholder = false;

  @override
  void initState() {
    super.initState();
    _checkImageSize();
  }

  Future<void> _checkImageSize() async {
    try {
      // Load the image and get its dimensions
      final imageProvider = CachedNetworkImageProvider(widget.imageUrl);
      final imageStream = imageProvider.resolve(const ImageConfiguration());

      imageStream.addListener(ImageStreamListener((info, _) {
        final width = info.image.width;
        final height = info.image.height;

        // Check if it's a tiny placeholder image
        if (width <= 1 || height <= 1 || (width * height) < 100) {
          // This is a placeholder, trigger fallback
          if (mounted) {
            setState(() {
              _isPlaceholder = true;
            });
            // Call the callback after the current frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onPlaceholderDetected();
            });
          }
        } else {
          // Real image, show it
          if (mounted) {
            setState(() {
              _isChecking = false;
            });
          }
        }
      }, onError: (error, stackTrace) {
        // On error, trigger fallback
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onPlaceholderDetected();
          });
        }
      }));
    } catch (e) {
      // On error, trigger fallback
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onPlaceholderDetected();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaceholder) {
      // Show placeholder while waiting for next URL to try
      return widget.placeholderBuilder();
    }

    if (_isChecking) {
      // Show placeholder while checking image size
      return widget.placeholderBuilder();
    }

    // Show the actual image
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      placeholder: (context, url) => widget.placeholderBuilder(),
      errorWidget: (context, url, error) {
        // On error, try next URL
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onPlaceholderDetected();
        });
        return widget.placeholderBuilder();
      },
      // Generous caching settings for book covers
      memCacheWidth: 600,           // Higher quality memory cache
      maxHeightDiskCache: 1000,      // Preserve high-quality images on disk
      cacheKey: widget.imageUrl,     // Custom cache key for reliable caching
      fadeInDuration: const Duration(milliseconds: 200), // Smooth fade-in
      fadeOutDuration: const Duration(milliseconds: 100), // Smooth fade-out
      // Web-specific optimizations

    );
  }
}
