import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/services/logging_service.dart';
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

  AuthState _state = const AuthInitial();
  AuthState get state => _state;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.checkLoginStatusUseCase,
    required this.getCurrentUserUseCase,
    required this.initiateOAuthLoginUseCase,
    required this.handleOAuthCallbackUseCase,
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
      (_) {
        // Clear image cache on successful logout
        // Note: CachedNetworkImage doesn't have a built-in method to clear all cache
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
            } catch (launchError) {
              LoggingService.error('🔑 [AuthNotifier] External launch failed, trying platform default: $launchError');
              
              // Fallback to default launch mode
              await launchUrlString(properlyEncodedUrl);
              LoggingService.debug('🔑 [AuthNotifier] Successfully launched OAuth URL with default mode');
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
    
    _emit(const AuthLoading());

    LoggingService.debug('🔑 [AuthNotifier] Calling handleOAuthCallback use case...');
    final result = await handleOAuthCallbackUseCase(code: code, state: state);

    result.fold(
      (failure) {
        LoggingService.error('🔑 [AuthNotifier] OAuth callback handling failed: ${failure.message}');
        _emit(AuthError(failure.message));
      },
      (user) {
        LoggingService.debug('🔑 [AuthNotifier] OAuth callback handling successful');
        LoggingService.debug('🔑 [AuthNotifier] Authenticated user: ${user.username}');
        _emit(Authenticated(user));
      },
    );
  }
}
