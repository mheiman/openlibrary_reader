import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/services/logging_service.dart';
import '../../../../core/services/oauth_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/usecases/check_login_status.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/handle_oauth_callback.dart';
import '../../domain/usecases/initiate_oauth_login.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import 'auth_state.dart';

/// Auth state notifier
@lazySingleton
class AuthNotifier extends ChangeNotifier {
  final Login loginUseCase;
  final Logout logoutUseCase;
  final CheckLoginStatus checkLoginStatusUseCase;
  final GetCurrentUser getCurrentUserUseCase;
  final InitiateOAuthLogin initiateOAuthLoginUseCase;
  final HandleOAuthCallback handleOAuthCallbackUseCase;
  final SecureStorageService secureStorage;
  final OAuthService oauthService;

  AuthState _state = const AuthInitial();
  AuthState get state => _state;

  // Track the last processed code to prevent duplicate handling
  String? _lastProcessedCode;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.checkLoginStatusUseCase,
    required this.getCurrentUserUseCase,
    required this.initiateOAuthLoginUseCase,
    required this.handleOAuthCallbackUseCase,
    required this.secureStorage,
    required this.oauthService,
  });

  /// Update state and notify listeners
  void _emit(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Login with username and password
  Future<void> login(String username, String password) async {
    _emit(const AuthLoading());

    final result = await loginUseCase(username: username, password: password);

    result.fold(
      (failure) => _emit(AuthError(failure.message)),
      (user) => _emit(Authenticated(user)),
    );
  }

  /// Logout current user
  Future<void> logout() async {
    _emit(const AuthLoading());

    final result = await logoutUseCase();

    result.fold(
      (failure) => _emit(AuthError(failure.message)),
      (_) async {
        // Clear OAuth tracking
        _lastProcessedCode = null;

        // Revoke OAuth tokens on logout for better security
        try {
          LoggingService.debug('🔑 [AuthNotifier] Revoking OAuth tokens on logout');
          
          // Get current tokens if available
          final accessToken = await secureStorage.read('oauth_access_token');
          final refreshToken = await secureStorage.read('oauth_refresh_token');
          
          if (accessToken != null || refreshToken != null) {
            await oauthService.revokeTokens(
              accessToken ?? '',
              refreshToken: refreshToken,
            );
          }
        } catch (e) {
          LoggingService.warning('🔑 [AuthNotifier] Failed to revoke tokens on logout: $e');
          // Continue with logout even if token revocation fails
        }

        // Clear image caches on successful logout
        try {
          // Clear Flutter's built-in image cache
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();

          // Clear CachedNetworkImage's cache
          await DefaultCacheManager().emptyCache();

          LoggingService.debug('Image caches cleared on logout');
        } catch (e) {
          LoggingService.warning('Failed to clear image cache: $e');
        }

        _emit(const Unauthenticated('Logged out successfully'));
      },
    );
  }

  /// Check if user is logged in
  Future<void> checkLoginStatus({bool forceCheck = false}) async {
    final result = await checkLoginStatusUseCase(forceCheck: forceCheck);

    result.fold(
      (failure) => _emit(const Unauthenticated()),
      (isLoggedIn) async {
        if (isLoggedIn) {
          // Check if OAuth token is expired before getting user info
          try {
            final tokenData = await secureStorage.read('oauth_tokens');
            if (tokenData != null) {
              final tokenMap = json.decode(tokenData) as Map<String, dynamic>;
              if (oauthService.isTokenExpired(tokenMap)) {
                LoggingService.debug('🔑 [AuthNotifier] Token expired, forcing re-authentication');
                _emit(const Unauthenticated());
                return;
              }
            }
          } catch (e) {
            LoggingService.warning('🔑 [AuthNotifier] Error checking token expiration: $e');
            // Continue with login check even if we can't verify token expiration
          }

          // Get current user info
          final userResult = await getCurrentUserUseCase();
          userResult.fold(
            (failure) => _emit(const Unauthenticated()),
            (user) => _emit(Authenticated(user)),
          );
        } else {
          _emit(const Unauthenticated());
        }
      },
    );
  }

  /// Initialize - check if user is already logged in
  Future<void> initialize() async {
    await checkLoginStatus();
  }

  /// Initiate OAuth login flow
  Future<void> initiateOAuthLogin() async {
    LoggingService.debug('🔑 [AuthNotifier] Initiating OAuth login flow');
    LoggingService.debug('🔑 [AuthNotifier] This will open the default browser for authentication');
    _emit(const AuthLoading());

    LoggingService.debug('🔑 [AuthNotifier] Calling initiateOAuthLogin use case...');
    final result = await initiateOAuthLoginUseCase();

    result.fold(
      (failure) {
        LoggingService.error('🔑 [AuthNotifier] OAuth login initiation failed: ${failure.message}');
        _emit(AuthError(failure.message));
      },
      (authUrl) async {
        LoggingService.debug('🔑 [AuthNotifier] OAuth login initiation successful');
        LoggingService.debug('🔑 [AuthNotifier] Authorization URL: $authUrl');
        
        // Launch the OAuth authorization URL in browser
        LoggingService.debug('🔑 [AuthNotifier] Attempting to launch OAuth URL in browser...');
        LoggingService.debug('🔑 [AuthNotifier] URL: $authUrl');
        
        try {
          LoggingService.debug('🔑 [AuthNotifier] Checking if URL can be launched...');
          LoggingService.debug('🔑 [AuthNotifier] Full URL: $authUrl');
          
          // Parse and re-encode the URL to ensure proper encoding
          final uri = Uri.parse(authUrl);
          LoggingService.debug('🔑 [AuthNotifier] Parsed URI scheme: ${uri.scheme}');
          LoggingService.debug('🔑 [AuthNotifier] Parsed URI host: ${uri.host}');
          LoggingService.debug('🔑 [AuthNotifier] Parsed URI path: ${uri.path}');
          LoggingService.debug('🔑 [AuthNotifier] Parsed URI query: ${uri.query}');
          
          // Reconstruct the URL with proper encoding
          final properlyEncodedUrl = uri.toString();
          LoggingService.debug('🔑 [AuthNotifier] Properly encoded URL: $properlyEncodedUrl');
          
          // Try launching with different modes
          final canLaunch = await canLaunchUrlString(properlyEncodedUrl);
          LoggingService.debug('🔑 [AuthNotifier] canLaunchUrlString result: $canLaunch');
          
          if (canLaunch) {
            LoggingService.debug('🔑 [AuthNotifier] URL is launchable, attempting to launch...');
            
            // Use launch with universal links option for better iOS support
            try {
              await launchUrlString(
                properlyEncodedUrl,
                mode: LaunchMode.externalApplication, // Force external browser
              );
              LoggingService.debug('🔑 [AuthNotifier] Successfully launched OAuth URL in external browser');

              // Return to unauthenticated state so user can still use login form if they return
              _emit(const Unauthenticated());
            } catch (launchError) {
              LoggingService.error('🔑 [AuthNotifier] External launch failed, trying platform default: $launchError');

              // Fallback to default launch mode
              await launchUrlString(properlyEncodedUrl);
              LoggingService.debug('🔑 [AuthNotifier] Successfully launched OAuth URL with default mode');

              // Return to unauthenticated state so user can still use login form if they return
              _emit(const Unauthenticated());
            }
          } else {
            LoggingService.error('🔑 [AuthNotifier] Failed to launch OAuth login URL - cannot launch URL');
            LoggingService.error('🔑 [AuthNotifier] URL scheme: ${uri.scheme}');
            LoggingService.error('🔑 [AuthNotifier] URL host: ${uri.host}');
            LoggingService.error('🔑 [AuthNotifier] URL path: ${uri.path}');
            _emit(AuthError('Could not launch OAuth login URL. Please check the URL: $authUrl'));
          }
        } catch (e, stackTrace) {
          LoggingService.error('🔑 [AuthNotifier] Exception launching OAuth URL: $e');
          LoggingService.error('🔑 [AuthNotifier] Exception stack trace: $stackTrace');
          
          // Provide specific error messages for common issues
          if (authUrl.startsWith('http://localhost') || authUrl.startsWith('http://127.0.0.1')) {
            _emit(AuthError('Cannot use localhost for OAuth on mobile devices. Use your computer\'s IP address or ngrok tunneling.'));
          } else if (authUrl.startsWith('http://')) {
            _emit(AuthError('HTTP URLs may be blocked for OAuth flows. Try using HTTPS or check your server configuration.'));
          } else if (e.toString().contains('Safari') || e.toString().contains('invalid')) {
            _emit(AuthError('Safari cannot open this URL. This might be due to URL encoding issues or iOS security restrictions.'));
          } else if (e.toString().contains('SafariViewController')) {
            _emit(AuthError('Failed to launch Safari View Controller. Trying external browser instead.'));
          } else {
            _emit(AuthError('Failed to launch OAuth login: ${e.toString()}'));
          }
        }
      },
    );
  }

  /// Handle OAuth callback
  Future<void> handleOAuthCallback(String code, String state) async {
    LoggingService.debug('🔑 [AuthNotifier] Handling OAuth callback');
    LoggingService.debug('🔑 [AuthNotifier] Authorization code: $code');
    LoggingService.debug('🔑 [AuthNotifier] State: $state');

    // Prevent duplicate processing of the same authorization code
    if (_lastProcessedCode == code) {
      LoggingService.debug('🔑 [AuthNotifier] Ignoring duplicate OAuth callback for same code');
      return;
    }
    _lastProcessedCode = code;

    _emit(const AuthLoading());

    LoggingService.debug('🔑 [AuthNotifier] Calling handleOAuthCallback use case...');
    final result = await handleOAuthCallbackUseCase(code: code, state: state);

    result.fold(
      (failure) {
        LoggingService.error('🔑 [AuthNotifier] OAuth callback handling failed: ${failure.message}');
        _lastProcessedCode = null; // Clear on failure so it can be retried
        _emit(AuthError(failure.message));
      },
      (user) {
        LoggingService.debug('🔑 [AuthNotifier] OAuth callback handling successful');
        LoggingService.debug('🔑 [AuthNotifier] Authenticated user: ${user.username}');
        _emit(Authenticated(user));
      },
    );
  }

  /// Handle manual OAuth code entry
  /// Retrieves the stored OAuth state and processes the manually entered code
  Future<void> handleManualOAuthCode(String code) async {
    LoggingService.debug('🔑 [AuthNotifier] Handling manual OAuth code entry');
    LoggingService.debug('🔑 [AuthNotifier] Authorization code: $code');

    // Retrieve the stored OAuth state
    final state = await secureStorage.read('oauth_state');

    if (state == null || state.isEmpty) {
      LoggingService.error('🔑 [AuthNotifier] No OAuth state found in storage');
      _emit(const AuthError(
        'No active OAuth session found. Please start the login process again.',
      ));
      return;
    }

    LoggingService.debug('🔑 [AuthNotifier] Retrieved stored state: $state');

    // Use the existing handleOAuthCallback method
    await handleOAuthCallback(code, state);
  }

  /// Clear stale OAuth data from secure storage
  /// Called when landing on login page to prevent incomplete OAuth flows from interfering
  void clearStaleOAuthData() {
    LoggingService.debug('🔑 [AuthNotifier] Clearing stale OAuth data');
    // Clear OAuth-related data asynchronously without blocking UI
    oauthService.clearOAuthData().catchError((error) {
      LoggingService.warning('Failed to clear stale OAuth data: $error');
    });
  }
}
