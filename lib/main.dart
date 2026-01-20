import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/logging_service.dart';
import 'core/storage/preferences_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/state/auth_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI to respect safe areas
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Configure dependency injection
  configureDependencies();

  // Initialize services that need async initialization
  await getIt<PreferencesService>().init();

  // Initialize auth and check if user is already logged in
  final authNotifier = getIt<AuthNotifier>();
  await authNotifier.initialize();

  // Set up deep link handling for OAuth callbacks
  _setupDeepLinkHandling(authNotifier);

  runApp(const MyApp());
}

/// Set up deep link handling for OAuth callbacks
void _setupDeepLinkHandling(AuthNotifier authNotifier) {
  final appLinks = AppLinks();

  // Handle initial deep link if app was launched with one
  _handleInitialUri(appLinks, authNotifier);

  // Handle deep links while app is running
  appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri, authNotifier);
    }
  }, onError: (err) {
    // Handle errors
    debugPrint('Error handling deep link: $err');
  });
}

/// Handle initial URI if app was launched with a deep link
Future<void> _handleInitialUri(AppLinks appLinks, AuthNotifier authNotifier) async {
  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri, authNotifier);
    }
  } catch (e) {
    debugPrint('Error getting initial URI: $e');
  }
}

/// Handle deep link
Future<void> _handleDeepLink(Uri uri, AuthNotifier authNotifier) async {
  LoggingService.debug('🔑 [DeepLink] Received deep link: $uri');

  // Check if this is an OAuth callback - support both custom scheme and universal links
  bool isOAuthCallback = false;
  String? code;
  String? state;

  // Check for custom scheme format: com.openlibrary.reader://oauth2/callback?code=...&state=...
  if (uri.scheme == 'com.openlibrary.reader' &&
      uri.host == 'oauth2' &&
      uri.path == '/callback') {
    isOAuthCallback = true;
    code = uri.queryParameters['code'];
    state = uri.queryParameters['state'];
  }
  // Check for universal link format: https://olreader.page.link/oauth?code=...&state=...
  else if (uri.host == 'olreader.page.link' &&
           uri.path == '/oauth') {
    isOAuthCallback = true;
    code = uri.queryParameters['code'];
    state = uri.queryParameters['state'];
  }
  // Check for direct GitHub Pages format: https://mheiman.github.io/openlibrary_reader/oauth-redirect.html?code=...&state=...
  else if (uri.host == 'mheiman.github.io' &&
           uri.path == '/openlibrary_reader/oauth-redirect.html') {
    isOAuthCallback = true;
    code = uri.queryParameters['code'];
    state = uri.queryParameters['state'];
  }

  if (isOAuthCallback) {
    LoggingService.debug('🔑 [DeepLink] Identified as OAuth callback');
    LoggingService.debug('🔑 [DeepLink] Query parameters: ${uri.queryParameters}');

    if (code != null && state != null) {
      final callbackKey = '$code:$state';
      final secureStorage = getIt<SecureStorageService>();

      // First check: Have we already processed this exact callback?
      final lastProcessed = await secureStorage.read('last_oauth_callback');
      if (lastProcessed == callbackKey) {
        LoggingService.debug('🔑 [DeepLink] Ignoring duplicate OAuth callback (already processed)');
        return;
      }

      // Second check: Is there an active OAuth session for this state?
      // If oauth_state doesn't exist or doesn't match, this is a stale callback from a previous session
      final storedState = await secureStorage.read('oauth_state');
      if (storedState != state) {
        LoggingService.debug('🔑 [DeepLink] Ignoring stale OAuth callback (no matching session)');
        // Mark as processed to prevent future retries
        await secureStorage.write('last_oauth_callback', callbackKey);
        return;
      }

      LoggingService.debug('🔑 [DeepLink] Handling OAuth callback with code: $code, state: $state');

      // Store this callback as processed before handling it
      await secureStorage.write('last_oauth_callback', callbackKey);

      // Handle the OAuth callback
      authNotifier.handleOAuthCallback(code, state);
    } else {
      LoggingService.error('🔑 [DeepLink] Invalid OAuth callback: missing code or state');
      if (code == null) LoggingService.error('🔑 [DeepLink] Missing authorization code');
      if (state == null) LoggingService.error('🔑 [DeepLink] Missing state parameter');
    }
  } else {
    LoggingService.debug('🔑 [DeepLink] Not an OAuth callback - ignoring');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _router = getIt<AppRouter>().router;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'OL Reader',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}
