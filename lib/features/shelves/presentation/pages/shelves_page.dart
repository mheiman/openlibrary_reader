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
    with TickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
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
    if (mounted) {
      // Schedule the update to happen after the current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTabController();
          setState(() {}); // Trigger rebuild if needed
        }
      });
    }
  }

  void _onShelvesStateChanged() {
    if (mounted) {
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

      // Update tab controller synchronously before rebuild to avoid mismatch
      if (state is ShelvesLoaded) {
        _updateTabController();
        // Schedule rebuild after controller is updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {}); // Trigger rebuild if needed
          }
        });
      }
    }
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

    if (state is ShelvesLoaded && settingsState is SettingsLoaded && _tabController != null) {
      final shelves = state.visibleShelves;
      final showLists = settingsState.settings.showLists;

      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Material(
          color: Theme
              .of(context)
              .colorScheme
              .surfaceContainerHigh,
          child: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            isScrollable: false,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${shelf.name} (${shelf.bookCount})'),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.sort, size: 20),
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
          ),
        ],
      ),
    );
  }

  Widget _buildListsTab(int listCount) {
    return Tab(
      child: Text('Lists ($listCount)'),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _shelvesNotifier,
      builder: (context, _) {
        final state = _shelvesNotifier.state;

        if (state is ShelvesLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (state is ShelvesError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading shelves',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(state.message),
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
          final showLists = settingsState is SettingsLoaded && settingsState.settings.showLists;

          if (shelves.isEmpty && (!showLists || state.bookLists.isEmpty)) {
            return const Center(
              child: Text('No shelves or lists configured'),
            );
          }

          // Calculate expected tab count
          final expectedTabCount = shelves.length + (showLists ? 1 : 0);

          // Ensure tab controller exists and has correct length
          if (_tabController == null || _tabController!.length != expectedTabCount) {
            // Update tab controller to match current state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateTabController();
              }
            });
            return const Center(child: CircularProgressIndicator());
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

        return const Center(
          child: Text('Welcome to OL Reader'),
        );
      },
    );
  }
}
