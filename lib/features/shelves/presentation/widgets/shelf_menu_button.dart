import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book.dart';
import '../state/shelves_notifier.dart';
import '../state/shelves_state.dart';
import 'add_to_list_dialog.dart';
import 'remove_from_list_dialog.dart';

/// A reusable popup menu button for managing book shelves and lists.
///
/// This widget centralizes the shelf/list management UI that appears on:
/// - Book covers (BookCover)
/// - Book info dialogs (WorkDetailsDialog)
/// - Reader page (ReaderPage)
class ShelfMenuButton extends StatelessWidget {
  /// The book to manage
  final Book book;

  /// Optional child widget for the button. If null, uses a default icon.
  final Widget? child;

  /// Icon to use if no child is provided
  final IconData icon;

  /// Color for the icon (if no child provided)
  final Color? iconColor;

  /// Tooltip for the button
  final String tooltip;

  /// Whether to show the "Add to List" option
  final bool showAddToList;

  /// Whether to show the "Remove from List" option
  final bool showRemoveFromList;

  /// Whether to show the "Book Info" option
  final bool showBookInfo;

  /// Whether to show the "Change Edition" option
  final bool showChangeEdition;

  /// Whether to show the "Related Titles" option
  final bool showRelatedTitles;

  /// Callback when "Book Info" is selected
  final VoidCallback? onBookInfo;

  /// Callback when "Change Edition" is selected
  final VoidCallback? onChangeEdition;

  /// Callback when "Related Titles" is selected
  final VoidCallback? onRelatedTitles;

  /// Callback when a shelf action completes (move, remove, add to list)
  final VoidCallback? onShelfActionComplete;

  const ShelfMenuButton({
    super.key,
    required this.book,
    this.child,
    this.icon = Icons.more_horiz_outlined,
    this.iconColor,
    this.tooltip = 'Shelves',
    this.showAddToList = true,
    this.showRemoveFromList = false,
    this.showBookInfo = false,
    this.showChangeEdition = false,
    this.showRelatedTitles = false,
    this.onBookInfo,
    this.onChangeEdition,
    this.onRelatedTitles,
    this.onShelfActionComplete,
  });

  @override
  Widget build(BuildContext context) {
    final shelvesNotifier = getIt<ShelvesNotifier>();

    return ListenableBuilder(
      listenable: shelvesNotifier,
      builder: (context, _) {
        final state = shelvesNotifier.state;
        if (state is! ShelvesLoaded) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String>(
          tooltip: tooltip,
          onSelected: (action) => _handleMenuAction(
            context,
            action,
            shelvesNotifier,
            state,
          ),
          itemBuilder: (context) => _buildMenuItems(context, state, shelvesNotifier),
          icon: child == null
              ? Icon(icon, color: iconColor)
              : null,
          child: child,
        );
      },
    );
  }

  /// Find the current shelf key for the book
  String? _findCurrentShelfKey(ShelvesLoaded state) {
    for (final shelf in state.shelves) {
      if (shelf.books.any((b) => b.workId == book.workId)) {
        return shelf.key;
      }
    }
    return null;
  }

  /// Build menu items
  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    ShelvesLoaded state,
    ShelvesNotifier shelvesNotifier,
  ) {
    final menuItems = <PopupMenuEntry<String>>[];
    final currentShelfKey = _findCurrentShelfKey(state);

    // Add shelf options
    for (final shelf in state.shelves) {
      menuItems.add(
        PopupMenuItem<String>(
          value: shelf.key,
          enabled: shelf.key != currentShelfKey,
          child: Text(shelf.name),
        ),
      );
    }

    // Add Remove option if book is on a shelf
    if (currentShelfKey != null) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_remove',
          child: Text('Remove from Shelf'),
        ),
      );
    }

    // Add divider before list/extra options
    menuItems.add(const PopupMenuDivider());

    // Add "Add to List" option if enabled and has lists
    if (showAddToList && state.bookLists.isNotEmpty) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_addToList',
          child: Text('Add to List'),
        ),
      );
    }

    // Add "Remove from List" option if enabled and has selected list
    if (showRemoveFromList && state.selectedListUrl != null) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_removeFromList',
          child: Text('Remove from List'),
        ),
      );
    }

    // Add extra options
    if (showBookInfo) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_bookInfo',
          child: Text('Book Info'),
        ),
      );
    }

    if (showChangeEdition) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_changeEdition',
          child: Text('Change Edition'),
        ),
      );
    }

    if (showRelatedTitles) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: '_relatedTitles',
          child: Text('Related Titles'),
        ),
      );
    }

    return menuItems;
  }

  /// Handle menu action
  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    ShelvesNotifier shelvesNotifier,
    ShelvesLoaded state,
  ) async {
    switch (action) {
      case '_remove':
        await _removeFromShelf(context, shelvesNotifier);
        break;
      case '_addToList':
        await _showAddToListDialog(context, shelvesNotifier, state);
        break;
      case '_removeFromList':
        await _removeFromList(context, shelvesNotifier, state);
        break;
      case '_bookInfo':
        onBookInfo?.call();
        break;
      case '_changeEdition':
        onChangeEdition?.call();
        break;
      case '_relatedTitles':
        onRelatedTitles?.call();
        break;
      default:
        // It's a shelf key - move book to that shelf
        await _moveToShelf(context, action, shelvesNotifier, state);
        break;
    }
  }

  /// Move book to a shelf
  Future<void> _moveToShelf(
    BuildContext context,
    String targetShelfKey,
    ShelvesNotifier shelvesNotifier,
    ShelvesLoaded state,
  ) async {
    final targetShelfName = state.shelves
        .firstWhere(
          (shelf) => shelf.key == targetShelfKey,
          orElse: () => state.shelves.first,
        )
        .name;

    await shelvesNotifier.moveBookToShelf(
      book: book,
      targetShelfKey: targetShelfKey,
    );

    onShelfActionComplete?.call();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: book.title, style: AppTheme.italic),
              TextSpan(text: ' added to $targetShelfName'),
            ],
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Remove book from shelf
  Future<void> _removeFromShelf(
    BuildContext context,
    ShelvesNotifier shelvesNotifier,
  ) async {
    await shelvesNotifier.moveBookToShelf(
      book: book,
      targetShelfKey: '-1',
    );

    onShelfActionComplete?.call();
  }

  /// Show dialog to select a list to add the book to
  Future<void> _showAddToListDialog(
    BuildContext context,
    ShelvesNotifier shelvesNotifier,
    ShelvesLoaded state,
  ) async {
    final selectedList = await showDialog<String>(
      context: context,
      builder: (context) => AddToListDialog(bookLists: state.bookLists),
    );

    if (selectedList == null || !context.mounted) return;

    try {
      await shelvesNotifier.addBookToList(
        book: book,
        listUrl: selectedList,
      );

      onShelfActionComplete?.call();

      if (!context.mounted) return;

      final listName = state.bookLists
          .firstWhere((list) => list.url == selectedList)
          .name;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Added '),
                TextSpan(text: book.title, style: AppTheme.italic),
                TextSpan(text: ' to $listName'),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding book to list: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Remove book from the currently selected list
  Future<void> _removeFromList(
    BuildContext context,
    ShelvesNotifier shelvesNotifier,
    ShelvesLoaded state,
  ) async {
    final listName = state.bookLists
        .firstWhere((list) => list.url == state.selectedListUrl)
        .name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => RemoveFromListDialog(
        bookTitle: book.title,
        listName: listName,
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await shelvesNotifier.removeBookFromCurrentList(book: book);

      onShelfActionComplete?.call();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Removed '),
                TextSpan(text: book.title, style: AppTheme.italic),
                TextSpan(text: ' from $listName'),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing book from list: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
