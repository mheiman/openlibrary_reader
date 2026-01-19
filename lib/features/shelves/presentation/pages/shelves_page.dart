import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../../../settings/presentation/widgets/settings_drawer.dart';
import '../../domain/entities/shelf.dart';
import '../state/shelves_notifier.dart';
import '../state/shelves_state.dart';
import '../widgets/lists_view.dart';
import '../widgets/shelf_sort_dialog.dart';
import '../widgets/shelf_view.dart';

/// Main shelves page (home screen) with tabs
class ShelvesPage extends StatefulWidget {
  const ShelvesPage({super.key});

  @override
  State<ShelvesPage> createState() => _ShelvesPageState();
}

class _ShelvesPageState extends State<ShelvesPage>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  late final ShelvesNotifier _shelvesNotifier;
  late final SettingsNotifier _settingsNotifier;
  TabController? _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _refreshAnimationController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shelvesNotifier = getIt<ShelvesNotifier>();
    _settingsNotifier = getIt<SettingsNotifier>();
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _shelvesNotifier.addListener(_onShelvesStateChanged);
    _settingsNotifier.addListener(_onSettingsChanged);
    _shelvesNotifier.initialize();
    _settingsNotifier.loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shelvesNotifier.removeListener(_onShelvesStateChanged);
    _settingsNotifier.removeListener(_onSettingsChanged);
    _tabController?.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is visible and running - refresh loans when returning from reader
      _shelvesNotifier.refreshUserLoans();
    }
  }

  void _onSettingsChanged() {
    if (!mounted) return;

    // Update tab controller synchronously (in case showLists changed)
    _updateTabController();

    // Schedule rebuild via microtask to avoid calling setState during build
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onShelvesStateChanged() {
    if (!mounted) return;

    // Handle refresh animation separately to avoid issues
    final state = _shelvesNotifier.state;
    if (state is ShelvesLoaded && state.isRefreshing) {
      if (!_refreshAnimationController.isAnimating) {
        _refreshAnimationController.repeat();
      }
    } else {
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
    }

    // Update tab controller synchronously
    if (state is ShelvesLoaded) {
      _updateTabController();
    }

    // Schedule rebuild via microtask to avoid calling setState during build
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _updateTabController() {
    final state = _shelvesNotifier.state;
    final settingsState = _settingsNotifier.state;

    if (state is ShelvesLoaded && settingsState is SettingsLoaded) {
      final visibleShelves = state.visibleShelves;
      final showLists = settingsState.settings.showLists;

      // Calculate total tab count
      final tabCount = visibleShelves.length + (showLists ? 1 : 0);

      // Only update if tab count has changed
      if (_tabController == null || _tabController!.length != tabCount) {
        // Save reference to old controller and its current index
        final oldController = _tabController;
        final currentIndex = _tabController?.index ?? 0;

        // Create new controller immediately (don't dispose old one yet)
        _tabController = TabController(
          length: tabCount,
          vsync: this,
          // Preserve current tab index, ensuring it's valid for the new length
          initialIndex: currentIndex.clamp(0, tabCount - 1),
        );

        // Listen for tab changes to refresh stale shelves
        _tabController?.addListener(_onTabChanged);

        // Dispose old controller after current frame completes
        if (oldController != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldController.removeListener(_onTabChanged);
            oldController.dispose();
          });
        }

        // Check if current shelf is stale and refresh if needed
        _checkAndRefreshCurrentShelf();
      }
    }
  }

  void _onTabChanged() {
    if (!mounted || _tabController == null || _tabController!.indexIsChanging) {
      return;
    }

    // Check if the newly selected shelf is stale and refresh if needed
    _checkAndRefreshCurrentShelf();
  }

  void _checkAndRefreshCurrentShelf() {
    if (_tabController == null) return;

    final state = _shelvesNotifier.state;
    final settingsState = _settingsNotifier.state;

    if (state is! ShelvesLoaded || settingsState is! SettingsLoaded) return;

    // Don't trigger refresh if already refreshing
    if (state.isRefreshing) return;

    final visibleShelves = state.visibleShelves;
    final currentIndex = _tabController!.index;

    // Check if we're on a shelf tab (not the Lists tab)
    if (currentIndex < visibleShelves.length) {
      final currentShelf = visibleShelves[currentIndex];
      // Refresh if stale
      _shelvesNotifier.refreshShelfIfStale(currentShelf.key);
    }
  }

  String? _getCurrentShelfKey() {
    if (_tabController == null) return null;

    final state = _shelvesNotifier.state;
    if (state is! ShelvesLoaded) return null;

    final visibleShelves = state.visibleShelves;
    final currentIndex = _tabController!.index;

    // Check if we're on a shelf tab (not the Lists tab)
    if (currentIndex < visibleShelves.length) {
      return visibleShelves[currentIndex].key;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Open Library'),
        actions: [
          IconButton(
            icon: RotationTransition(
              turns: _refreshAnimationController,
              child: const Icon(Icons.refresh),
            ),
            onPressed: () {
              final shelfKey = _getCurrentShelfKey();
              if (shelfKey != null) {
                // Refresh the current shelf
                _shelvesNotifier.refreshShelf(shelfKey);
              } else {
                // We're on the Lists tab, refresh the selected list
                _shelvesNotifier.refreshCurrentList();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushToSearch(),
            tooltip: 'Search',
          ),
        ],
        bottom: _buildTabBar(),
      ),
      drawer: const SettingsDrawer(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget? _buildTabBar() {
    final state = _shelvesNotifier.state;
    final settingsState = _settingsNotifier.state;

    if (state is ShelvesLoaded &&
        settingsState is SettingsLoaded &&
        _tabController != null) {
      final shelves = state.visibleShelves;
      final showLists = settingsState.settings.showLists;

      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            isScrollable: false,
            labelPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 4),
            tabAlignment: TabAlignment.fill,
            controller: _tabController,
            tabs: [
              ...shelves.map((shelf) => _buildTab(shelf)),
              if (showLists) _buildListsTab(state.bookLists.length),
            ],
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildTab(Shelf shelf) {
    return Tab(
      child: Wrap(
        spacing: 5,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
          Text(
            shelf.name,
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 7,
            children: [
              Text('(${shelf.bookCount})'),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ShelfSortDialog(
                      shelf: shelf,
                      onSortChanged: (sortOrder, ascending) {
                        _shelvesNotifier.updateSort(
                          shelf.key,
                          sortOrder,
                          ascending,
                        );
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.sort, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListsTab(int listCount) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Lists ($listCount)'),
      ),
    );
  }

  Widget _buildBody() {
    // Note: We don't use ListenableBuilder here because _onShelvesStateChanged
    // already listens to the notifier and updates the tab controller BEFORE
    // triggering a rebuild via setState(). This ensures the tab controller
    // is always in sync when we build.
    final state = _shelvesNotifier.state;

    if (state is ShelvesLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state is ShelvesError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading shelves',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(state.message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  _shelvesNotifier.loadShelves(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _shelvesNotifier.loadShelves(forceRefresh: false),
              icon: const Icon(Icons.offline_pin),
              label: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else if (state is ShelvesLoaded) {
      final shelves = state.visibleShelves;
      final settingsState = _settingsNotifier.state;
      final showLists =
          settingsState is SettingsLoaded &&
          settingsState.settings.showLists;

      if (shelves.isEmpty && (!showLists || state.bookLists.isEmpty)) {
        return const Center(child: Text('No shelves or lists configured'));
      }

      // Calculate expected tab count
      final expectedTabCount = shelves.length + (showLists ? 1 : 0);

      // Ensure tab controller exists and matches - it should already be updated
      // by _onShelvesStateChanged before this rebuild was triggered
      if (_tabController == null || _tabController!.length != expectedTabCount) {
        // Controller not ready yet, update it now
        _updateTabController();
        // Re-check after update - if still mismatched, show loading
        if (_tabController == null || _tabController!.length != expectedTabCount) {
          return const Center(child: CircularProgressIndicator());
        }
      }

      return RefreshIndicator(
        onRefresh: () async {
          final shelfKey = _getCurrentShelfKey();
          if (shelfKey != null) {
            await _shelvesNotifier.refreshShelf(shelfKey);
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            ...shelves.map((shelf) {
              return ShelfView(
                shelf: shelf,
                onRefresh: () => _shelvesNotifier.refreshShelf(shelf.key),
              );
            }),
            if (showLists) ListsView(bookLists: state.bookLists),
          ],
        ),
      );
    }

    return const Center(child: Text('Welcome to OL Reader'));
  }
}
