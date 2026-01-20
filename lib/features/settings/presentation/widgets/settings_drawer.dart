import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/presentation/state/auth_notifier.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../shelves/presentation/state/shelves_notifier.dart';
import '../../../shelves/presentation/state/shelves_state.dart';
import '../../domain/entities/app_settings.dart';
import '../state/settings_notifier.dart';
import '../state/settings_state.dart';

/// Settings drawer that slides in from the left
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  late final SettingsNotifier _notifier;
  late final AuthNotifier _authNotifier;
  late final ShelvesNotifier _shelvesNotifier;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _notifier = getIt<SettingsNotifier>();
    _authNotifier = getIt<AuthNotifier>();
    _shelvesNotifier = getIt<ShelvesNotifier>();

    _loadAppVersion();

    // Load settings after the first frame to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _notifier.state is! SettingsLoaded) {
        _notifier.loadSettings();
      }
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  void _updateSetting(AppSettings settings) {
    _notifier.updateSetting(settings);
  }

  Future<void> _handleLoginLogout() async {
    final authState = _authNotifier.state;

    if (authState is Authenticated) {
      // Log out
      await _authNotifier.logout();
      if (mounted) {
        _shelvesNotifier.loadShelves(forceRefresh: true);
        Navigator.pop(context); // Close drawer
        context.goToLogin();
      }
    } else {
      // Navigate to login
      Navigator.pop(context); // Close drawer
      context.goToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      child: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          final state = _notifier.state;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.fromLTRB(16, 12 + topPadding, 16, 12),
                child: Text(
                  'Options',
                  style: Theme.of(context).textTheme.titleLarge
                ),
              ),

              // Settings content
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, SettingsState state) {
    if (state is SettingsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is SettingsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _notifier.loadSettings(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is SettingsLoaded) {
      final settings = state.settings;

      return ListView(
        padding: EdgeInsets.zero,
        children: [
          // Login/Logout
          ListenableBuilder(
            listenable: _authNotifier,
            builder: (context, _) {
              final authState = _authNotifier.state;
              final String title;

              if (authState is Authenticated) {
                title = 'Log out ${authState.user.displayName}';
              } else {
                title = 'Log in';
              }

              return ListTile(
                title: Text(title),
                onTap: _handleLoginLogout,
              );
            },
          ),

          const Divider(),

          // Help
          ListTile(
            title: const Text('Help'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              context.goToHelp();
            },
          ),

          const Divider(),

          SwitchListTile.adaptive(
            title: const Text('Move books to "Reading" shelf when borrowing'),
            value: settings.moveToReading,
            onChanged: (value) {
              _updateSetting(settings.copyWith(moveToReading: value));
            },
          ),

          SwitchListTile.adaptive(
            title: const Text('Show time/battery in full-screen reading mode'),
            value: settings.showChrome,
            onChanged: (value) {
              _updateSetting(settings.copyWith(showChrome: value));
            },
          ),

          SwitchListTile.adaptive(
            title: const Text('Prevent screen from sleeping while reading'),
            value: settings.keepAwake,
            onChanged: (value) {
              _updateSetting(settings.copyWith(keepAwake: value));
            },
          ),

          const Divider(),

          // Dark Mode
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode', style: Theme.of(context).listTileTheme.titleTextStyle),
                const SizedBox(height: 8),
                Center(
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AppSettings.darkModeOff, label: Text('Off')),
                      ButtonSegment(value: AppSettings.darkModeOn, label: Text('On')),
                      ButtonSegment(value: AppSettings.darkModeAuto, label: Text('Auto')),
                    ],
                    selected: {settings.darkMode},
                    onSelectionChanged: (Set<String> selection) {
                      final value = selection.first;
                      _updateSetting(settings.copyWith(darkMode: value));
                      AppTheme.setDarkMode(value);
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Cover Size Slider
          ListTile(
            title: Row(
              children: [
                const Expanded(child: Text('Cover Size')),
                Text(
                  '${settings.coverWidth.round()} px',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            subtitle: Slider(
              value: settings.coverWidth,
              min: AppSettings.minCoverWidth,
              max: AppSettings.maxCoverWidth,
              divisions: 80,
              label: '${settings.coverWidth.round()} px',
              onChanged: (value) {
                _updateSetting(settings.copyWith(coverWidth: value));
              },
            ),
          ),

          const Divider(),

          // Shelves to Show header
          const ListTile(
            title: Text('Shelves to Show'),
            contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          ),

          // Shelves visibility switches
          ListenableBuilder(
            listenable: _shelvesNotifier,
            builder: (context, _) {
              final shelvesState = _shelvesNotifier.state;
              if (shelvesState is! ShelvesLoaded) {
                return const SizedBox.shrink();
              }

              final shelves = shelvesState.shelves;
              final widgets = <Widget>[];

              // Add shelf switches
              for (final shelf in shelves) {
                widgets.add(
                  SwitchListTile.adaptive(
                    title: Text(shelf.olName),
                    visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                    value: shelf.isVisible,
                    contentPadding: const EdgeInsets.fromLTRB(64, 0, 16, 0),
                    onChanged: (value) async {
                      await _shelvesNotifier.updateShelfVisibility(
                        shelfKey: shelf.key,
                        isVisible: value,
                      );
                    },
                  ),
                );
              }

              // Add Lists switch
              widgets.add(
                SwitchListTile.adaptive(
                  title: const Text('Lists (Experimental)'),
                  visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                  value: settings.showLists,
                  contentPadding: const EdgeInsets.fromLTRB(64, 0, 16, 0),
                  onChanged: (value) {
                    _updateSetting(settings.copyWith(showLists: value));
                  },
                ),
              );

              return Column(children: widgets);
            },
          ),

          const Divider(),

          // Version
          ListTile(
            title: Row(
              children: [
                const Expanded(child: Text('Version')),
                Text(
                  _appVersion.isNotEmpty ? _appVersion : 'Loading...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
