import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/logging_service.dart';
import 'core/storage/preferences_service.dart';
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
void _handleDeepLink(Uri uri, AuthNotifier authNotifier) {
  LoggingService.debug('🔑 [DeepLink] Received deep link: $uri');
  
  // Check if this is an OAuth callback
  if (uri.scheme == 'com.openlibrary.reader' && 
      uri.host == 'oauth2' && 
      uri.path == '/callback') {
    
    LoggingService.debug('🔑 [DeepLink] Identified as OAuth callback');
    
    // Extract code and state from query parameters
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    
    LoggingService.debug('🔑 [DeepLink] Query parameters: ${uri.queryParameters}');
    
    if (code != null && state != null) {
      LoggingService.debug('🔑 [DeepLink] Handling OAuth callback with code: $code, state: $state');
      
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

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>().router;

    return MaterialApp.router(
      title: 'OL Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
