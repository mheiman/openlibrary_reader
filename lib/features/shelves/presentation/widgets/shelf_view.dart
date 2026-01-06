import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../../domain/entities/shelf.dart';
import 'book_grid.dart';

/// Widget to display a single shelf with book covers
class ShelfView extends StatefulWidget {
  final Shelf shelf;
  final VoidCallback onRefresh;

  const ShelfView({
    super.key,
    required this.shelf,
    required this.onRefresh,
  });

  @override
  State<ShelfView> createState() => _ShelfViewState();
}

class _ShelfViewState extends State<ShelfView> {
  late final SettingsNotifier _settingsNotifier;

  @override
  void initState() {
    super.initState();
    _settingsNotifier = getIt<SettingsNotifier>();
    // Load settings after the first frame to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _settingsNotifier.state is! SettingsLoaded) {
        _settingsNotifier.loadSettings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.shelf.sortedBooks;

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No books in ${widget.shelf.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add books using the search feature',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: _settingsNotifier,
      builder: (context, _) {
        final state = _settingsNotifier.state;
        final coverWidth = state is SettingsLoaded
            ? state.settings.coverWidth
            : AppSettings.defaultCoverWidth;

        return BookGrid(
          books: books,
          currentShelfKey: widget.shelf.key,
          coverWidth: coverWidth,
        );
      },
    );
  }
}
