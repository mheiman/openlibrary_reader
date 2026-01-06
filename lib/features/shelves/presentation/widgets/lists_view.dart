import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../../domain/entities/book_list.dart';
import '../state/shelves_notifier.dart';
import '../state/shelves_state.dart';
import 'list_folder_chip.dart';
import 'list_item_grid.dart';

/// View displaying user's book lists with horizontal folder selector
/// and book grid for selected list contents
class ListsView extends StatefulWidget {
  final List<BookList> bookLists;

  const ListsView({
    super.key,
    required this.bookLists,
  });

  @override
  State<ListsView> createState() => _ListsViewState();
}

class _ListsViewState extends State<ListsView> {
  late final ShelvesNotifier _shelvesNotifier;
  late final SettingsNotifier _settingsNotifier;

  @override
  void initState() {
    super.initState();
    _shelvesNotifier = getIt<ShelvesNotifier>();
    _settingsNotifier = getIt<SettingsNotifier>();

    // Load settings if needed
    if (_settingsNotifier.state is! SettingsLoaded) {
      _settingsNotifier.loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookLists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No lists found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create lists on openlibrary.org',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Horizontal scrolling folder selector
        _buildFolderSelector(),

        // Book grid for selected list
        Expanded(
          child: _buildBookGrid(),
        ),
      ],
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
    //    color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
      ),
      child: ListenableBuilder(
        listenable: _shelvesNotifier,
        builder: (context, _) {
          final state = _shelvesNotifier.state;
          final selectedListUrl = state is ShelvesLoaded ? state.selectedListUrl : null;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.bookLists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final bookList = widget.bookLists[index];
              final isSelected = selectedListUrl == bookList.url;

              return ListFolderChip(
                bookList: bookList,
                isSelected: isSelected,
                onTap: () {
                  if (isSelected) {
                    // Tapping selected list clears selection
                    _shelvesNotifier.clearListSelection();
                  } else {
                    // Select new list
                    _shelvesNotifier.selectList(bookList.url);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookGrid() {
    return ListenableBuilder(
      listenable: _shelvesNotifier,
      builder: (context, _) {
        final state = _shelvesNotifier.state;

        if (state is! ShelvesLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        // Show loading indicator while fetching list contents
        if (state.isLoadingListContents) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Show empty state if no list selected
        if (state.selectedListUrl == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a list to view its contents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        // Show empty state if list has no books
        if (state.listBooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'This list is empty',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add books to this list on openlibrary.org',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          );
        }

        // Show books in grid
        return ListenableBuilder(
          listenable: _settingsNotifier,
          builder: (context, _) {
            final settingsState = _settingsNotifier.state;
            final coverWidth = settingsState is SettingsLoaded
                ? settingsState.settings.coverWidth
                : AppSettings.defaultCoverWidth;

            return ListItemGrid(
              items: state.listBooks,
              currentShelfKey: '', // Lists don't have a shelf key
              coverWidth: coverWidth,
              showChangeEdition: false, // Hide "Change Edition" on lists
              showRelatedTitles: false, // Hide "Related Titles" on lists
              showRemoveFromList: true, // Show "Remove from List" on lists
            );
          },
        );
      },
    );
  }
}
