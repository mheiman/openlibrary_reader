import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/domain/usecases/update_settings.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../../../shelves/domain/entities/book.dart';
import '../../../shelves/presentation/state/shelves_notifier.dart';
import '../../../shelves/presentation/state/shelves_state.dart';
import '../../../shelves/presentation/widgets/book_cover.dart';
import '../../../shelves/presentation/widgets/book_grid_config.dart';
import '../state/search_notifier.dart';
import '../state/search_state.dart';
import '../widgets/search_sort_dialog.dart';

/// Search filter type
enum SearchFilter {
  all('All'),
  author('Author'),
  title('Title');

  final String label;

  const SearchFilter(this.label);
}

/// Search page
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final ShelvesNotifier _shelvesNotifier;
  late final SearchNotifier _searchNotifier;
  late final SettingsNotifier _settingsNotifier;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final _openLibraryHeaderKey = GlobalKey();
  List<Book> _localResults = [];
  Map<String, String> _bookShelfMap = {}; // Map book workId to shelf key
  bool _showOpenLibraryResults = false;
  List<Book> _openLibraryBooks = []; // Cache converted books
  SearchFilter _searchFilter = SearchFilter.all;
  bool _isLoadingMore = false;
  bool _isLoadingInitial = false;
  bool _hasMore = true;
  bool _isSearchLoaded = false;
  double _coverWidth = AppSettings.defaultCoverWidth;
  String _lastOpenLibraryQuery = ''; // Track the last OpenLibrary search query
  Uri? _lastProcessedUri; // Track the last processed URI to avoid re-applying params

  @override
  void initState() {
    super.initState();
    _shelvesNotifier = getIt<ShelvesNotifier>();
    _searchNotifier = getIt<SearchNotifier>();
    _settingsNotifier = getIt<SettingsNotifier>();

    // Listen to search text changes
    _searchController.addListener(_onSearchTextChanged);

    // Listen to scroll events for pagination
    _scrollController.addListener(_onScroll);

    // Listen to search state changes to update cached books
    _searchNotifier.addListener(_onSearchStateChanged);

    // Load settings and check for query parameters after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _settingsNotifier.state is! SettingsLoaded) {
        _settingsNotifier.loadSettings();
      }

      // Update cover width from settings
      if (mounted) {
        final state = _settingsNotifier.state;
        if (state is SettingsLoaded) {
          setState(() {
            _coverWidth = state.settings.coverWidth;
          });
        }
      }

      // Check for query parameters and pre-populate search
      _checkQueryParameters();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _scrollController.removeListener(_onScroll);
    _searchNotifier.removeListener(_onSearchStateChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check query parameters whenever dependencies change (including route updates)
    // This handles the case where we're already on the search page and navigate to it
    // again with different query parameters (e.g., from Book Info dialog)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueryParameters();
    });
  }

  void _onSearchStateChanged() {
    if (!mounted) return;

    final state = _searchNotifier.state;

    setState(() {
      // Update loading and pagination state
      _isLoadingMore = state is SearchLoading && state.isLoadingMore;
      _isLoadingInitial = state is SearchLoading && !state.isLoadingMore;
      _isSearchLoaded = state is SearchLoaded;
      _hasMore = state is SearchLoaded ? state.result.hasMore : true;

      // Update book list if loaded
      if (state is SearchLoaded) {
        // Get all books on shelves, mapped by work ID
        final shelvesState = _shelvesNotifier.state;
        final shelfBooksByWorkId = <String, Book>{};
        final shelfKeyByWorkId = <String, String>{};

        if (shelvesState is ShelvesLoaded) {
          for (final shelf in shelvesState.shelves) {
            for (final book in shelf.books) {
              shelfBooksByWorkId[book.workId] = book;
              shelfKeyByWorkId[book.workId] = shelf.key;
            }
          }
        }

        // Find works from remote results that are already on shelves
        // and add them to local results if not already present
        final localWorkIds = _localResults.map((b) => b.workId).toSet();
        for (final work in state.result.works) {
          if (shelfBooksByWorkId.containsKey(work.workId) &&
              !localWorkIds.contains(work.workId)) {
            _localResults.add(shelfBooksByWorkId[work.workId]!);
            _bookShelfMap[work.workId] = shelfKeyByWorkId[work.workId]!;
            localWorkIds.add(work.workId);
          }
        }
        _localResults = _sortBooks(_localResults);

        // Filter out works that are already on shelves from remote results
        final books = state.result.works
            .where((work) => !shelfBooksByWorkId.containsKey(work.workId))
            .map((work) {
              return Book(
                editionId: work.lendingEdition ?? '',
                workId: work.workId,
                title: work.title,
                authors: work.authors,
                coverImageId: work.coverImageId != null
                    ? int.tryParse(work.coverImageId!)
                    : null,
                publishDate: work.firstPublishYear?.toString(),
                availability: work.availability,
              );
            })
            .toList();
        _openLibraryBooks = _sortBooks(books);

        // Only auto-scroll for the first page
        if (state.result.currentPage == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ctx = _openLibraryHeaderKey.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.1,
              );
            }
          });
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.8) {
      return;
    }

    final state = _searchNotifier.state;

    final isLoadingMore = state is SearchLoading && state.isLoadingMore;

    if (state is SearchLoaded && state.result.hasMore && !isLoadingMore) {
      _searchNotifier.loadMore();
    }
  }

  void _onSearchTextChanged() {
    if (!mounted) return;

    final query = _searchController.text.trim();

    if (query.length < 2) {
      setState(() {
        _localResults = [];
        _bookShelfMap = {};
        // Clear OpenLibrary results when search is cleared
        _showOpenLibraryResults = false;
        _openLibraryBooks = [];
        _lastOpenLibraryQuery = '';
      });
      _searchNotifier.clearSearch();
      return;
    }

    // Search local shelves
    final shelvesState = _shelvesNotifier.state;
    if (shelvesState is ShelvesLoaded) {
      final allBooks = <Book>[];
      final newBookShelfMap = <String, String>{};

      for (final shelf in shelvesState.shelves) {
        for (final book in shelf.books) {
          allBooks.add(book);
          newBookShelfMap[book.workId] = shelf.key;
        }
      }

      // Filter books by title or author based on selected filter
      // Split query into tokens - all tokens must be present for a match
      final tokens = query.toLowerCase().split(RegExp(r'\s+'));
      final results = allBooks.where((book) {
        switch (_searchFilter) {
          case SearchFilter.all:
            // Check if all tokens are present in either title or author fields
            return tokens.every((token) {
              final titleMatch = book.title.toLowerCase().contains(token);
              final authorMatch = book.authors.any(
                (author) => author.toLowerCase().contains(token),
              );
              return titleMatch || authorMatch;
            });
          case SearchFilter.author:
            // All tokens must be present in author fields
            return tokens.every((token) {
              return book.authors.any(
                (author) => author.toLowerCase().contains(token),
              );
            });
          case SearchFilter.title:
            // All tokens must be present in title
            final lowerTitle = book.title.toLowerCase();
            return tokens.every((token) => lowerTitle.contains(token));
        }
      }).toList();

      setState(() {
        _localResults = _sortBooks(results);
        _bookShelfMap = newBookShelfMap;

        // Clear OpenLibrary results only if search text differs from last search
        if (_showOpenLibraryResults && query != _lastOpenLibraryQuery) {
          _showOpenLibraryResults = false;
          _openLibraryBooks = [];
          _searchNotifier.clearSearch();
        }
      });
    }
  }

  /// Check for query parameters and pre-populate search
  void _checkQueryParameters() {
    if (!mounted) return;

    final uri = GoRouterState.of(context).uri;

    // Only process if the URI has actually changed (new navigation)
    // This prevents re-applying params when dialogs close or other dependency changes occur
    if (_lastProcessedUri != null && _lastProcessedUri == uri) {
      return;
    }
    _lastProcessedUri = uri;

    final queryParam = uri.queryParameters['query'];
    final filterParam = uri.queryParameters['filter'];

    if (queryParam != null && queryParam.isNotEmpty) {
      // Only update if different from current values
      final newFilter = filterParam != null
          ? switch (filterParam.toLowerCase()) {
              'author' => SearchFilter.author,
              'title' => SearchFilter.title,
              _ => SearchFilter.all,
            }
          : SearchFilter.all;

      final shouldUpdate =
          _searchController.text != queryParam || _searchFilter != newFilter;

      if (shouldUpdate && mounted) {
        _searchFilter = newFilter;
        // Set the search text (this will trigger _onSearchTextChanged via listener)
        _searchController.text = queryParam;
        // Clear any existing OpenLibrary results when params change
        _showOpenLibraryResults = false;
        _openLibraryBooks = [];

        // Use setState only if not already wrapped in addPostFrameCallback
        if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
          setState(() {});
        }
      }
    }
  }

  void _performOpenLibrarySearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _searchFocusNode.unfocus();
      setState(() {
        _showOpenLibraryResults = true;
        _openLibraryBooks = []; // Clear cached books when starting new search
        _lastOpenLibraryQuery = query; // Track this search query
      });

      // Format query based on search filter
      final formattedQuery = switch (_searchFilter) {
        SearchFilter.all => query,
        SearchFilter.author => 'author:$query',
        SearchFilter.title => 'title:$query',
      };

      // Get sort parameter
      final sortParam = _getApiSortParameter();

      _searchNotifier.searchWithSort(formattedQuery, sortParam);
    }
  }

  /// Get current search sort order from settings
  SearchSortOrder _getCurrentSortOrder() {
    final state = _settingsNotifier.state;
    if (state is SettingsLoaded) {
      return _searchSortOrderFromString(state.settings.searchSortOrder);
    }
    return SearchSortOrder.datePublished;
  }

  /// Get current search sort ascending from settings
  bool _getCurrentSortAscending() {
    final state = _settingsNotifier.state;
    if (state is SettingsLoaded) {
      return state.settings.searchSortAscending;
    }
    return true;
  }

  /// Convert string to SearchSortOrder enum
  SearchSortOrder _searchSortOrderFromString(String value) {
    switch (value) {
      case 'title':
        return SearchSortOrder.title;
      case 'author':
        return SearchSortOrder.author;
      case 'datePublished':
      default:
        return SearchSortOrder.datePublished;
    }
  }

  /// Convert SearchSortOrder enum to string
  String _searchSortOrderToString(SearchSortOrder order) {
    switch (order) {
      case SearchSortOrder.title:
        return 'title';
      case SearchSortOrder.author:
        return 'author';
      case SearchSortOrder.datePublished:
        return 'datePublished';
    }
  }

  /// Get OpenLibrary API sort parameter
  String? _getApiSortParameter() {
    final sortOrder = _getCurrentSortOrder();
    final ascending = _getCurrentSortAscending();

    switch (sortOrder) {
      case SearchSortOrder.datePublished:
        return ascending ? 'old' : 'new';
      case SearchSortOrder.title:
        return ascending ? 'title' : 'title_desc';
      case SearchSortOrder.author:
        // WORKAROUND: OpenLibrary API has a bug with author sorting
        // Don't send author sort parameter - we'll sort locally instead
        // TODO: Re-enable when API is fixed
        // return ascending ? 'author' : 'author_desc';
        return null; // Sort locally instead
    }
  }

  /// Sort books list based on current sort settings
  List<Book> _sortBooks(
    List<Book> books, {
    SearchSortOrder? sortOrder,
    bool? ascending,
  }) {
    final booksCopy = List<Book>.from(books);
    final actualSortOrder = sortOrder ?? _getCurrentSortOrder();
    final actualAscending = ascending ?? _getCurrentSortAscending();

    int Function(Book, Book) comparator;
    switch (actualSortOrder) {
      case SearchSortOrder.title:
        comparator = (a, b) {
          final titleA = _getSortableTitle(a.title);
          final titleB = _getSortableTitle(b.title);
          return titleA.compareTo(titleB);
        };
        break;
      case SearchSortOrder.author:
        comparator = (a, b) {
          final authorA = a.authors.isNotEmpty
              ? a.authors.first.toLowerCase()
              : '';
          final authorB = b.authors.isNotEmpty
              ? b.authors.first.toLowerCase()
              : '';
          return authorA.compareTo(authorB);
        };
        break;
      case SearchSortOrder.datePublished:
        comparator = (a, b) {
          // Nulls sort to the end
          if (a.publishDate == null && b.publishDate == null) return 0;
          if (a.publishDate == null) return 1;
          if (b.publishDate == null) return -1;

          // Try to parse as integers (for years like "2020", "2019")
          final aYear = int.tryParse(a.publishDate!);
          final bYear = int.tryParse(b.publishDate!);

          if (aYear != null && bYear != null) {
            return aYear.compareTo(bYear);
          }

          // Fallback to string comparison
          return a.publishDate!.compareTo(b.publishDate!);
        };
        break;
    }

    // Apply direction
    if (actualAscending) {
      booksCopy.sort(comparator);
    } else {
      booksCopy.sort((a, b) => comparator(b, a));
    }

    return booksCopy;
  }

  /// Get sortable version of title with leading articles moved to end
  String _getSortableTitle(String title) {
    final lowerTitle = title.toLowerCase().trim();

    // Check for leading articles
    if (lowerTitle.startsWith('the ')) {
      return '${lowerTitle.substring(4)}, the';
    } else if (lowerTitle.startsWith('a ')) {
      return '${lowerTitle.substring(2)}, a';
    } else if (lowerTitle.startsWith('an ')) {
      return '${lowerTitle.substring(3)}, an';
    }

    return lowerTitle;
  }

  /// Show sort dialog and update settings
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => SearchSortDialog(
        currentSortOrder: _getCurrentSortOrder(),
        currentAscending: _getCurrentSortAscending(),
        onSortChanged: (sortOrder, ascending) async {
          final state = _settingsNotifier.state;
          if (state is SettingsLoaded) {
            // Update settings
            final updateSettings = getIt<UpdateSettings>();
            await updateSettings(
              settings: state.settings.copyWith(
                searchSortOrder: _searchSortOrderToString(sortOrder),
                searchSortAscending: ascending,
              ),
            );

            // Re-load settings to get updated values
            await _settingsNotifier.loadSettings();

            // Re-sort existing results with the new sort parameters
            if (mounted) {
              setState(() {
                _localResults = _sortBooks(
                  _localResults,
                  sortOrder: sortOrder,
                  ascending: ascending,
                );
                _openLibraryBooks = _sortBooks(
                  _openLibraryBooks,
                  sortOrder: sortOrder,
                  ascending: ascending,
                );
              });
            }
          }
        },
      ),
    );
  }

  /// Handle clipboard search for Open Library or Internet Archive URLs
  Future<void> _handleClipboardSearch() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      _showClipboardError('Copy an Open Library or Internet Archive book URL '
          'in your browser to search for it here.');
      return;
    }

    final uri = Uri.tryParse(text);
    if (uri == null) {
      _showClipboardError('Copy an Open Library or Internet Archive book URL '
          'in your browser to search for it here.');
      return;
    }

    final host = uri.host.toLowerCase();

    // Check for Open Library URLs
    if (host == 'openlibrary.org' || host == 'www.openlibrary.org') {
      final searchTerm = _parseOpenLibraryUrl(uri);
      if (searchTerm != null) {
        _setSearchFromClipboard(searchTerm);
      } else {
        _showClipboardError('No book identifiers found in URL.');
      }
      return;
    }

    // Check for Internet Archive URLs
    if (host == 'archive.org' || host == 'www.archive.org') {
      final searchTerm = _parseArchiveOrgUrl(uri);
      if (searchTerm != null) {
        _setSearchFromClipboard(searchTerm);
      } else {
        _showClipboardError('No book identifiers found in URL.');
      }
      return;
    }

    // Not a recognized URL
    _showClipboardError('Copy an Open Library or Internet Archive book URL '
        'in your browser to search for it here.');
  }

  /// Parse Open Library URL for book/work identifiers
  /// Returns search term like "key:/works/OL123W" or "edition_key:/books/OL456M"
  String? _parseOpenLibraryUrl(Uri uri) {
    final path = uri.path;

    // Look for /books/OL...M pattern (edition) - this takes priority
    final booksMatch = RegExp(r'/books/(OL\d+M)').firstMatch(path);
    if (booksMatch != null) {
      return 'edition_key:${booksMatch.group(1)}';
    }

    // Look for /works/OL...W pattern
    final worksMatch = RegExp(r'/works/(OL\d+W)').firstMatch(path);
    if (worksMatch != null) {
      return 'key:/works/${worksMatch.group(1)}';
    }

    return null;
  }

  /// Parse Archive.org URL for identifier
  /// Returns search term like "ia:identifier"
  String? _parseArchiveOrgUrl(Uri uri) {
    final path = uri.path;

    // Look for /details/IDENTIFIER pattern
    final detailsMatch = RegExp(r'/details/([^/?]+)').firstMatch(path);
    if (detailsMatch != null) {
      return 'ia:${detailsMatch.group(1)}';
    }

    return null;
  }

  /// Set search field from clipboard result and trigger search
  void _setSearchFromClipboard(String searchTerm) {
    setState(() {
      _searchFilter = SearchFilter.all;
      _searchController.text = searchTerm;
    });
    _performOpenLibrarySearch();
  }

  /// Show clipboard error dialog
  void _showClipboardError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clipboard'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // If we can pop, do that, otherwise go back to shelves
            if (context.canGoBack) {
              context.goBack();
            } else {
              context.goToShelves();
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Search'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _handleClipboardSearch,
            tooltip: 'Search from clipboard URL',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Sort results',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field and button
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Flex(
                  direction: Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 75,
                      child: DropdownButton<SearchFilter>(
                        value: _searchFilter,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: SearchFilter.values.map((filter) {
                          return DropdownMenuItem(
                            value: filter,
                            alignment: Alignment.centerRight,
                            child: Text(filter.label),
                          );
                        }).toList(),
                        onChanged: (SearchFilter? newFilter) {
                          if (newFilter != null) {
                            setState(() {
                              _searchFilter = newFilter;
                            });
                            _onSearchTextChanged();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search for books...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _showOpenLibraryResults = false;
                                    });
                                    _searchNotifier.clearSearch();
                                  },
                                )
                              : null,
                        ),
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _performOpenLibrarySearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Show icon-only button on small screens, text button on larger screens
                    if (constraints.maxWidth < 450)
                      ElevatedButton(
                        onPressed: _searchController.text.trim().isEmpty
                            ? null
                            : _performOpenLibrarySearch,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Icon(Icons.search),
                      )
                    else
                      ElevatedButton(
                        onPressed: _searchController.text.trim().isEmpty
                            ? null
                            : _performOpenLibrarySearch,
                        child: const Text('Search OpenLibrary'),
                      ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          // Results
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: 1000, // Cache more items to reduce rebuilds
              slivers: [
                // Local shelf results
                if (_localResults.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Results from your shelves',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: BookGridConfig.defaultPadding,
                    sliver: SliverGrid(
                      gridDelegate: BookGridConfig.createGridDelegate(
                        coverWidth: _coverWidth,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = _localResults[index];
                          final shelfKey = _bookShelfMap[book.workId] ?? '';
                          return BookCover(
                            key: ValueKey(book.workId),
                            book: book,
                            currentShelfKey: shelfKey,
                            coverWidth: _coverWidth,
                            showChangeEdition: false,
                            showRelatedTitles: false,
                          );
                        },
                        childCount: _localResults.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
                ],

                // OpenLibrary results
                if (_showOpenLibraryResults) ...[
                  SliverToBoxAdapter(
                    key: _openLibraryHeaderKey,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Results from OpenLibrary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),

                  // Show loading spinner for initial search
                  if (_isLoadingInitial && _openLibraryBooks.isEmpty)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),

                  if (_openLibraryBooks.isNotEmpty)
                    SliverPadding(
                      padding: BookGridConfig.defaultPadding,
                      sliver: SliverGrid(
                        gridDelegate: BookGridConfig.createGridDelegate(
                          coverWidth: _coverWidth,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final book = _openLibraryBooks[index];
                          return BookCover(
                            key: ValueKey(book.workId),
                            book: book,
                            currentShelfKey: '',
                            coverWidth: _coverWidth,
                            showChangeEdition: false,
                            showRelatedTitles: false,
                          );
                        }, childCount: _openLibraryBooks.length),
                      ),
                    ),

                  // Loading more indicator, no results message, or end of results message
                  _buildLoadingOrEndMessage(),
                ],

                // Empty state
                if (_localResults.isEmpty && !_showOpenLibraryResults)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start typing to search your shelves',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrEndMessage() {
    // Use local state instead of listening to notifier
    if (_isLoadingMore) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_isSearchLoaded) {
      // Show "No results found" if there are no books and not loading initial results
      if (_openLibraryBooks.isEmpty && !_isLoadingInitial) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No results found',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          ),
        );
      }

      // Show "End of search results" if there are books but no more pages
      if (!_hasMore) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'End of search results',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          ),
        );
      }
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}
