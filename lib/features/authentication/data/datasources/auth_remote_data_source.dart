import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

/// Remote data source for authentication
@lazySingleton
class AuthRemoteDataSource {
  final DioClient dioClient;
  final SecureStorageService secureStorage;
  final CookieManager cookieManager;

  String? _cookieHeader;
  bool _loggedIn = false;

  AuthRemoteDataSource(
    this.dioClient,
    this.secureStorage,
  ) : cookieManager = CookieManager.instance();

  /// Login with username and password
  ///
  /// Returns [UserModel] on success
  /// Throws [AuthException] on failure
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    try {
      // Clear existing cookies
      await cookieManager.deleteAllCookies();

      // Step 1: POST login credentials
      final response = await dioClient.post(
        '${ApiConstants.openLibraryBaseUrl}${ApiConstants.loginPath}',
        data: {
          'username': username,
          'password': password,
          'redirect': '/',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 303) {
        // Extract cookies from response
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          await _setCookieHeader(cookies.join('; '));
        }

        // Verify login by checking if we're logged in
        // TODO: Re-enable proper login verification
        // final isLoggedIn = await _verifyLogin();
        
        // Store credentials for auto-login
        await secureStorage.write('username', username);
        await secureStorage.write('password', password);

        // Get user info
        final user = await _getUserInfo();
        _loggedIn = true;
        return user;
      } else {
        if (response.statusCode == 200) {
          throw const AuthException('Login failed. Please check your credentials.', 200);
        } else {
          throw AuthException(
            'Login failed: ${response.statusMessage}',
            response.statusCode,
          );
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Invalid username or password', 401);
      }
      throw NetworkException(e.message ?? 'Network error during login');
    } catch (e) {
      // Rethrow any AppException (includes NetworkException, AuthException, etc.)
      if (e is AppException) rethrow;
      throw AuthException('Login failed: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      // Clear cookies
      await cookieManager.deleteAllCookies();
      _cookieHeader = null;
      _loggedIn = false;

      // Clear stored credentials
      await secureStorage.delete('username');
      await secureStorage.delete('password');
      await secureStorage.delete('userId');
      await secureStorage.delete('displayName');
    } catch (e) {
      throw CacheException('Logout failed: $e');
    }
  }

  /// Check if user is logged in
  ///
  /// [forceCheck] - Force check with server instead of using cached status
  Future<bool> isLoggedIn({bool forceCheck = false}) async {
    if (_loggedIn && !forceCheck) {
      return true;
    }

    try {
      // Try to get stored cookies
      await _loadStoredCookies();

      if (_cookieHeader != null) {
        final isValid = await _verifyLogin();
        _loggedIn = isValid;
        return isValid;
      }

      return false;
    } catch (e) {
      _loggedIn = false;
      return false;
    }
  }

  /// Get current user info
  Future<UserModel> getCurrentUser() async {
    if (!_loggedIn) {
      throw const AuthException('Not logged in');
    }

    try {
      return await _getUserInfo();
    } catch (e) {
      throw AuthException('Failed to get user info: $e');
    }
  }

  /// Get stored credentials
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final username = await secureStorage.read('username');
      final password = await secureStorage.read('password');

      if (username != null && password != null) {
        return {'username': username, 'password': password};
      }
      return null;
    } catch (e) {
      throw CacheException('Failed to get stored credentials: $e');
    }
  }

  /// Verify login by checking account page
  Future<bool> _verifyLogin() async {
    try {
      if (_cookieHeader == null) return false;

      // Make a GET request to /account (not /account/login which doesn't accept GET)
      final response = await dioClient.get(
        '${ApiConstants.openLibraryBaseUrl}/account',
        options: Options(
          headers: {'Cookie': _cookieHeader},
          validateStatus: (status) => status! < 500, // Accept any non-server-error status
        ),
      );

      // If we get a successful response and it's not redirecting to login, we're logged in
      // The account page will contain user info if logged in, or redirect to login if not
      final responseStr = response.data.toString();
      return response.statusCode == 200 &&
             !responseStr.contains('account/login') &&
             responseStr.isNotEmpty;
    } catch (e) {
      LoggingService.debug('Session verification failed: $e');
      return false;
    }
  }

  /// Get user information from cookie
  Future<UserModel> _getUserInfo() async {
    if (_cookieHeader == null) {
      throw const AuthException('No session cookie available');
    }

    // Extract user ID from cookie
    final RegExp userIdReg = RegExp(r'session=/people/(.*)%2C');
    String userId = '';

    if (userIdReg.hasMatch(_cookieHeader!)) {
      userId = userIdReg.firstMatch(_cookieHeader!)!.group(1) ?? '';
    }

    // Get username from secure storage
    final username = await secureStorage.read('username') ?? '';

    // Try to get display name (default to username if not available)
    String displayName = username;
    try {
      final response = await dioClient.get(
        '${ApiConstants.openLibraryBaseUrl}${ApiConstants.accountEndpoint}',
        options: Options(
          headers: {'Cookie': _cookieHeader},
        ),
      );

      // Try to extract displayname from response
      final RegExp displayNameReg = RegExp(r'displayname["\s:]+([^"]+)"');
      if (displayNameReg.hasMatch(response.data.toString())) {
        displayName = displayNameReg.firstMatch(response.data.toString())!.group(1) ?? username;
      }
    } catch (e) {
      // If we can't get display name, use username
    }

    return UserModel(
      userId: userId,
      username: username,
      displayName: displayName,
    );
  }

  /// Load cookies from cookie manager
  Future<void> _loadStoredCookies() async {
    try {
      final url = WebUri(ApiConstants.openLibraryBaseUrl);
      final cookies = await cookieManager.getCookies(url: url);

      if (cookies.isNotEmpty) {
        final sessionCookie = cookies.firstWhere(
          (c) => c.name == 'session',
          orElse: () => Cookie(name: '', value: ''),
        );

        if (sessionCookie.value.isNotEmpty) {
          _cookieHeader = 'session=${sessionCookie.value}';
          return;
        }
      }

      // Fallback: try secure storage (survives hot reload and app restarts)
      final sessionValue = await secureStorage.read('session_cookie');
      if (sessionValue != null && sessionValue.isNotEmpty) {
        _cookieHeader = 'session=$sessionValue';

        // Restore cookie to cookie manager so WebView can use it
        try {
          await cookieManager.setCookie(
            url: url,
            name: 'session',
            value: sessionValue,
            domain: 'openlibrary.org',
            path: '/',
            isSecure: true,
          );
        } catch (e) {
        }
      } else {
        _cookieHeader = null;
      }
    } catch (e) {
      _cookieHeader = null;
    }
  }

  /// Set cookie header from Set-Cookie header value
  Future<void> _setCookieHeader(String setCookieHeader) async {
    final RegExp cookieReg = RegExp(r'session=([^;]+)');
    if (cookieReg.hasMatch(setCookieHeader)) {
      final match = cookieReg.firstMatch(setCookieHeader);
      final sessionValue = match!.group(1)!;
      _cookieHeader = 'session=$sessionValue';

      // Save to secure storage as backup (survives hot reload)
      try {
        await secureStorage.write('session_cookie', sessionValue);
      } catch (e) {
      }

      // Save cookie to cookie manager for persistence
      try {
        final url = WebUri(ApiConstants.openLibraryBaseUrl);
        await cookieManager.setCookie(
          url: url,
          name: 'session',
          value: sessionValue,
          domain: 'openlibrary.org',
          path: '/',
          isSecure: true,
        );
      } catch (e) {
      }
    }
  }

  /// Get cookie header (for use by other services)
  String? get cookieHeader {
    // If cookie not in memory, try to load from cookie manager
    if (_cookieHeader == null) {
      // This is synchronous, so we can't await here
      // The caller should ensure cookies are loaded first
      // by calling isLoggedIn() before using cookieHeader
    }
    return _cookieHeader;
  }

  /// Ensure cookies are loaded (call this before using cookieHeader)
  Future<void> ensureCookiesLoaded() async {
    if (_cookieHeader == null) {
      await _loadStoredCookies();
    }
  }
}
