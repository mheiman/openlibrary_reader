import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injectable/injectable.dart';

import '../error/exceptions.dart';
import '../network/api_constants.dart';
import '../network/dio_client.dart';
import '../services/logging_service.dart';
import '../storage/secure_storage_service.dart';
import 'dart:math' as math;

/// OAuth service for handling OAuth2 flows
@lazySingleton
class OAuthService {
  final DioClient dioClient;
  final SecureStorageService secureStorage;
  final CookieManager cookieManager;

  OAuthService(this.dioClient, this.secureStorage)
    : cookieManager = CookieManager.instance();

  /// Generate a random string for PKCE code verifier
  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (i) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate PKCE code verifier and challenge
  Future<Map<String, String>> _generatePKCE() async {
    final codeVerifier = _generateRandomString(64);
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    final codeChallenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    
    return {
      'code_verifier': codeVerifier,
      'code_challenge': codeChallenge,
    };
  }

  /// Generate OAuth2 authorization URL
  Future<String> generateAuthorizationUrl() async {
    LoggingService.debug('🔑 [OAuth] Starting OAuth authorization flow');

    // Clear any previous OAuth callback tracking to allow new flow
    await secureStorage.delete('last_oauth_callback');

    LoggingService.debug('🔑 [OAuth] Generating PKCE code verifier and challenge...');
    final pkce = await _generatePKCE();
    final state = _generateRandomString(16);

    LoggingService.debug('🔑 [OAuth] Generated PKCE code verifier: ${pkce['code_verifier']}');
    LoggingService.debug('🔑 [OAuth] Generated PKCE code challenge: ${pkce['code_challenge']}');
    LoggingService.debug('🔑 [OAuth] Generated state: $state');

    // Store PKCE and state for later verification
    LoggingService.debug('🔑 [OAuth] Storing PKCE and state in secure storage...');
    await secureStorage.write('oauth_code_verifier', pkce['code_verifier']!);
    await secureStorage.write('oauth_state', state);
    
    // Handle redirect_uri carefully - custom schemes can cause issues in Safari
    String redirectUri = ApiConstants.oauthRedirectUri;
    
    // Apply different encoding strategies based on configuration
    if (redirectUri.contains('://') && !redirectUri.startsWith('http')) {
      switch (ApiConstants.oauthRedirectUriEncoding) {
        case 'raw':
          // Use the URL as-is without encoding the scheme
          LoggingService.debug('🔑 [OAuth] Using raw custom URL scheme: $redirectUri');
          break;
          
        case 'http':
          // Fallback to HTTP redirect (recommended for production)
          LoggingService.error('🔑 [OAuth] Custom URL schemes not recommended. Consider using HTTP redirect.');
          break;
          
        case 'minimal':
          // Encode only the colon, leave slashes as-is
          redirectUri = redirectUri.replaceAll(':', '%3A');
          LoggingService.debug('🔑 [OAuth] Using minimal encoding: $redirectUri');
          break;
          
        case 'partial':
          // Encode colon and both slashes
          redirectUri = redirectUri.replaceFirst('://', '%3A%2F%2F');
          LoggingService.debug('🔑 [OAuth] Using partial encoding: $redirectUri');
          break;
          
        case 'encoded':
        default:
          // Use standard encoding
          redirectUri = redirectUri.replaceAll('://', '%3A%2F%2F');
          LoggingService.debug('🔑 [OAuth] Using full encoding: $redirectUri');
          break;
      }
    }
    
    final params = {
      'response_type': 'code',
      'client_id': ApiConstants.oauthClientId,
      'redirect_uri': redirectUri,
      'scope': ApiConstants.oauthScope,
      'state': state,
      'code_challenge': pkce['code_challenge'],
      'code_challenge_method': 'S256',
    };
    
    // Add cache-busting only if enabled (can be disabled for testing)
    if (ApiConstants.oauthUseMinimalParameters) {
      params['_'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    LoggingService.debug('🔑 [OAuth] OAuth parameters: $params');
    
    // Build query string carefully to avoid double encoding
    final queryString = params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${e.value}') // Don't encode value if we already encoded it
      .join('&');
    
    // Final URL construction with validation
    final authUrl = '${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthAuthorizePath}?$queryString';
    
    // Validate URL length and encoding
    LoggingService.debug('🔑 [OAuth] Final URL length: ${authUrl.length} characters');
    if (authUrl.length > 2000) {
      LoggingService.error('🔑 [OAuth] URL is very long (${authUrl.length} chars), may cause issues on some browsers');
    }
    
    LoggingService.debug('🔑 [OAuth] Generated authorization URL: $authUrl');
    if (ApiConstants.oauthUseMinimalParameters) {
      LoggingService.debug('🔑 [OAuth] Added cache-busting parameter');
    }
    LoggingService.debug('🔑 [OAuth] Authorization flow initiated successfully');
    
    return authUrl;
  }

  /// Exchange authorization code for tokens
  Future<Map<String, dynamic>> exchangeCodeForTokens(String code, String state) async {
    LoggingService.debug('🔑 [OAuth] Starting token exchange process');
    LoggingService.debug('🔑 [OAuth] Received authorization code: $code');
    LoggingService.debug('🔑 [OAuth] Received state: $state');
    
    // Add timestamp to track when this token was issued
    final issuedAt = DateTime.now().millisecondsSinceEpoch;
    
    try {
      // Verify state matches what we stored
      LoggingService.debug('🔑 [OAuth] Verifying state parameter...');
      final storedState = await secureStorage.read('oauth_state');
      if (storedState != state) {
        LoggingService.error('🔑 [OAuth] State mismatch! Expected: $storedState, Got: $state');
        throw const AuthException('Invalid OAuth state', 400);
      }
      LoggingService.debug('🔑 [OAuth] State verification successful');
      
      // Get PKCE code verifier
      LoggingService.debug('🔑 [OAuth] Retrieving PKCE code verifier from secure storage...');
      final codeVerifier = await secureStorage.read('oauth_code_verifier');
      if (codeVerifier == null) {
        LoggingService.error('🔑 [OAuth] PKCE code verifier not found in secure storage');
        throw const AuthException('Missing PKCE code verifier', 400);
      }
      LoggingService.debug('🔑 [OAuth] Retrieved PKCE code verifier: $codeVerifier');
      
      // Clean up stored values
      LoggingService.debug('🔑 [OAuth] Cleaning up secure storage...');
      await secureStorage.delete('oauth_state');
      await secureStorage.delete('oauth_code_verifier');
      
      // Exchange code for tokens
      LoggingService.debug('🔑 [OAuth] Exchanging authorization code for tokens...');
      LoggingService.debug('🔑 [OAuth] Token endpoint: ${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthTokenPath}');

      // Log request parameters (redact sensitive values in production)
      final requestData = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': ApiConstants.oauthRedirectUri,
        'client_id': ApiConstants.oauthClientId,
        'client_secret': ApiConstants.oauthClientSecret,
        'code_verifier': codeVerifier,
      };
      LoggingService.error('🔑 [OAuth] ===== TOKEN REQUEST PARAMETERS =====');
      LoggingService.error('  - grant_type: ${requestData['grant_type']}');
      LoggingService.error('  - code: ${code.substring(0, math.min(10, code.length))}...${code.length > 10 ? code.substring(code.length - 10) : ""}');
      LoggingService.error('  - redirect_uri: ${requestData['redirect_uri']}');
      LoggingService.error('  - client_id: ${requestData['client_id']}');
      LoggingService.error('  - client_secret: ${requestData['client_secret']}');
      LoggingService.error('  - code_verifier: ${codeVerifier.substring(0, math.min(10, codeVerifier.length))}...${codeVerifier.length > 10 ? codeVerifier.substring(codeVerifier.length - 10) : ""}');
      LoggingService.error('🔑 [OAuth] ==========================================');

      Response response;
      try {
        response = await dioClient.dio.post(
          '${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthTokenPath}',
          data: requestData,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
      } on DioException catch (dioError) {
        // Catch DioException here - it may already be wrapped by interceptor
        LoggingService.error('🔑 [OAuth] Raw DioException caught:');
        LoggingService.error('  - Type: ${dioError.type}');
        LoggingService.error('  - Message: ${dioError.message}');
        LoggingService.error('  - Error object type: ${dioError.error.runtimeType}');
        LoggingService.error('  - Error object: ${dioError.error}');
        LoggingService.error('  - Status Code: ${dioError.response?.statusCode}');
        LoggingService.error('  - Response Data Type: ${dioError.response?.data.runtimeType}');

        // Check if the error was already converted by interceptor
        if (dioError.error is AppException) {
          final appException = dioError.error as AppException;
          LoggingService.error('  - Wrapped AppException: $appException');

          // Check if we actually got an HTTP response
          if (dioError.response == null) {
            LoggingService.error('  - No HTTP response received (server may have crashed or timed out)');
            throw AuthException(
              'OAuth token request failed: No response from server. '
              'The server may be down, crashed while processing, or the request timed out.',
              null,
            );
          }

          // If we have a status code, use it
          final statusCode = dioError.response!.statusCode;
          throw AuthException(
            'OAuth server rejected token request ($statusCode ${dioError.response!.statusMessage}). '
            'Check server logs for details.',
            statusCode,
          );
        }

        if (dioError.response?.data is String) {
          final htmlData = dioError.response?.data as String;
          // Extract useful info from HTML error if possible
          if (htmlData.contains('<title>')) {
            final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(htmlData);
            if (titleMatch != null) {
              LoggingService.error('  - HTML Error Title: ${titleMatch.group(1)}');
            }
          }
          LoggingService.error('  - Response is HTML (${htmlData.length} chars)');
        } else if (dioError.response?.data is Map) {
          LoggingService.error('  - Response Data: ${dioError.response?.data}');
        }

        // Re-throw to be caught by outer handler
        rethrow;
      }

      LoggingService.debug('🔑 [OAuth] Token exchange response status: ${response.statusCode}');
      LoggingService.debug('🔑 [OAuth] Token exchange response data: ${response.data}');
      
      if (response.statusCode == 200) {
        LoggingService.debug('🔑 [OAuth] Token exchange successful!');
        
        // Add token metadata to the response
        final tokenData = response.data as Map<String, dynamic>;
        tokenData['issued_at'] = issuedAt;
        
        // Calculate expiration time (default to 1 hour if not provided)
        final expiresIn = (tokenData['expires_in'] as num?)?.toInt() ?? 3600;
        final expiresAt = issuedAt + (expiresIn * 1000);
        tokenData['expires_at'] = expiresAt;
        
        LoggingService.debug('🔑 [OAuth] Token expires in $expiresIn seconds (at ${DateTime.fromMillisecondsSinceEpoch(expiresAt)})');
        
        return tokenData;
      } else {
        LoggingService.error('🔑 [OAuth] Token exchange failed with status ${response.statusCode}: ${response.statusMessage}');
        throw AuthException('Token exchange failed: ${response.statusMessage}', response.statusCode);
      }
    } on DioException catch (e) {
      LoggingService.error('🔑 [OAuth] DioException during token exchange: ${e.message}');
      LoggingService.error('🔑 [OAuth] DioException type: ${e.type}');
      LoggingService.error('🔑 [OAuth] Response status code: ${e.response?.statusCode}');
      LoggingService.error('🔑 [OAuth] Response data type: ${e.response?.data.runtimeType}');
      LoggingService.error('🔑 [OAuth] Response data: ${e.response?.data}');
      LoggingService.error('🔑 [OAuth] Response headers: ${e.response?.headers}');

      if (e.response?.statusCode == 400) {
        // Try to extract error details from response
        String errorMessage = 'Invalid OAuth request';

        if (e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          final error = errorData['error'];
          final errorDescription = errorData['error_description'];

          LoggingService.error('🔑 [OAuth] Server error: $error');
          LoggingService.error('🔑 [OAuth] Server error description: $errorDescription');

          if (errorDescription != null) {
            errorMessage = errorDescription.toString();
          } else if (error != null) {
            errorMessage = error.toString();
          }
        } else if (e.response?.data is String) {
          LoggingService.error('🔑 [OAuth] Server returned HTML/text error: ${e.response?.data}');
          errorMessage = 'Server returned error (check logs for details)';
        }

        throw AuthException('OAuth token exchange failed: $errorMessage', 400);
      }

      throw NetworkException(e.message ?? 'Network error during token exchange');
    } catch (e) {
      LoggingService.error('🔑 [OAuth] Exception during token exchange: $e');
      if (e is AppException) rethrow;
      throw AuthException('Token exchange failed: $e');
    }
  }

  /// Exchange OAuth tokens for session cookie
  Future<void> exchangeTokensForCookie(String accessToken) async {
    LoggingService.debug('🔑 [OAuth] Starting token to cookie exchange process');
    LoggingService.debug('🔑 [OAuth] Access token: $accessToken');
    
    try {
      LoggingService.debug('🔑 [OAuth] Exchanging access token for session cookie...');
      LoggingService.debug('🔑 [OAuth] Token-to-cookie endpoint: ${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthTokenToCookiePath}');
      
      final response = await dioClient.post(
        '${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthTokenToCookiePath}',
        data: {
          'access_token': accessToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      
      LoggingService.debug('🔑 [OAuth] Token-to-cookie response status: ${response.statusCode}');
      LoggingService.debug('🔑 [OAuth] Token-to-cookie response data: ${response.data}');
      
      if (response.statusCode == 200) {
        LoggingService.debug('🔑 [OAuth] Token-to-cookie exchange successful!');
        
        // Extract cookies from response
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          LoggingService.debug('🔑 [OAuth] Received cookies: $cookies');
          await _setCookieHeader(cookies.join('; '));
          LoggingService.debug('🔑 [OAuth] Session cookie stored successfully');
        } else {
          LoggingService.debug('🔑 [OAuth] No cookies received in response');
        }
      } else {
        LoggingService.error('🔑 [OAuth] Token-to-cookie exchange failed with status ${response.statusCode}: ${response.statusMessage}');
        throw AuthException('Token to cookie exchange failed: ${response.statusMessage}', response.statusCode);
      }
    } on DioException catch (e) {
      LoggingService.error('🔑 [OAuth] DioException during token-to-cookie exchange: ${e.message}');
      throw NetworkException(e.message ?? 'Network error during token to cookie exchange');
    } catch (e) {
      LoggingService.error('🔑 [OAuth] Exception during token-to-cookie exchange: $e');
      if (e is AppException) rethrow;
      throw AuthException('Token to cookie exchange failed: $e');
    }
  }

  /// Get user info using access token
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    LoggingService.debug('🔑 [OAuth] Starting user info retrieval');
    LoggingService.debug('🔑 [OAuth] Access token: $accessToken');
    
    try {
      LoggingService.debug('🔑 [OAuth] Fetching user info from OAuth userinfo endpoint...');
      LoggingService.debug('🔑 [OAuth] Userinfo endpoint: ${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthUserInfoPath}');
      
      final response = await dioClient.get(
        '${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthUserInfoPath}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      
      LoggingService.debug('🔑 [OAuth] Userinfo response status: ${response.statusCode}');
      LoggingService.debug('🔑 [OAuth] Userinfo response data: ${response.data}');
      
      if (response.statusCode == 200) {
        LoggingService.debug('🔑 [OAuth] User info retrieval successful!');
        return response.data as Map<String, dynamic>;
      } else {
        LoggingService.error('🔑 [OAuth] User info retrieval failed with status ${response.statusCode}: ${response.statusMessage}');
        throw AuthException('Failed to get user info: ${response.statusMessage}', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        LoggingService.error('🔑 [OAuth] Invalid access token - unauthorized');
        throw const AuthException('Invalid access token', 401);
      }
      LoggingService.error('🔑 [OAuth] Network error getting user info: ${e.message}');
      throw NetworkException(e.message ?? 'Network error getting user info');
    } catch (e) {
      LoggingService.error('🔑 [OAuth] Exception during user info retrieval: $e');
      if (e is AppException) rethrow;
      throw AuthException('Failed to get user info: $e');
    }
  }

  /// Set cookie header from Set-Cookie header value
  Future<void> _setCookieHeader(String setCookieHeader) async {
    final RegExp cookieReg = RegExp(r'session=([^;]+)');
    if (cookieReg.hasMatch(setCookieHeader)) {
      final match = cookieReg.firstMatch(setCookieHeader);
      final sessionValue = match!.group(1)!;

      // Save to secure storage as backup (survives hot reload and app restarts)
      try {
        await secureStorage.write('session_cookie', sessionValue);
        LoggingService.debug('🔑 [OAuth] Saved session cookie to secure storage');
      } catch (e) {
        LoggingService.warning('Failed to save OAuth cookie to secure storage: $e');
      }

      // Save cookie to cookie manager for WebView persistence
      try {
        final url = WebUri(ApiConstants.openLibraryBaseUrl);
        final uri = Uri.parse(ApiConstants.openLibraryBaseUrl);
        final domain = uri.host;
        final isSecure = uri.scheme == 'https';

        await cookieManager.setCookie(
          url: url,
          name: 'session',
          value: sessionValue,
          domain: domain,
          path: '/',
          isSecure: isSecure,
        );
        LoggingService.debug('🔑 [OAuth] Saved session cookie to CookieManager (domain: $domain, secure: $isSecure)');
      } catch (e) {
        LoggingService.warning('Failed to save OAuth cookie to CookieManager: $e');
      }
    }
  }

  /// Check if token is expired
  bool isTokenExpired(Map<String, dynamic> tokenData) {
    try {
      final expiresAt = tokenData['expires_at'] as int?;
      if (expiresAt == null) {
        LoggingService.warning('🔑 [OAuth] No expiration time in token data, assuming expired');
        return true;
      }
      
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final isExpired = currentTime >= expiresAt;
      
      if (isExpired) {
        LoggingService.debug('🔑 [OAuth] Token expired at ${DateTime.fromMillisecondsSinceEpoch(expiresAt)}');
      } else {
        final timeLeft = expiresAt - currentTime;
        final minutesLeft = (timeLeft / 1000 / 60).round();
        LoggingService.debug('🔑 [OAuth] Token expires in $minutesLeft minutes');
      }
      
      return isExpired;
    } catch (e) {
      LoggingService.error('🔑 [OAuth] Error checking token expiration: $e');
      return true; // Assume expired if we can't check
    }
  }

  /// Revoke OAuth tokens
  Future<void> revokeTokens(String accessToken, {String? refreshToken}) async {
    LoggingService.debug('🔑 [OAuth] Starting token revocation process');
    
    try {
      // Try to revoke access token
      if (accessToken.isNotEmpty) {
        try {
          LoggingService.debug('🔑 [OAuth] Revoking access token');
          
          // Note: OpenLibrary may not have a standard revocation endpoint
          // This is a placeholder for when/if they implement it
          // For now, we'll just log and clear local storage
          
          await secureStorage.delete('oauth_tokens');
          LoggingService.debug('🔑 [OAuth] Access token revoked (cleared from local storage)');
        } catch (e) {
          LoggingService.warning('🔑 [OAuth] Failed to revoke access token: $e');
        }
      }
      
      // Try to revoke refresh token if provided
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          LoggingService.debug('🔑 [OAuth] Revoking refresh token');
          
          // Note: OpenLibrary may not have a standard revocation endpoint
          // This is a placeholder for when/if they implement it
          
          await secureStorage.delete('oauth_refresh_token');
          LoggingService.debug('🔑 [OAuth] Refresh token revoked (cleared from local storage)');
        } catch (e) {
          LoggingService.warning('🔑 [OAuth] Failed to revoke refresh token: $e');
        }
      }
      
      // Clear session cookie as well
      try {
        await secureStorage.delete('session_cookie');
        LoggingService.debug('🔑 [OAuth] Session cookie cleared');
      } catch (e) {
        LoggingService.warning('🔑 [OAuth] Failed to clear session cookie: $e');
      }
      
      LoggingService.debug('🔑 [OAuth] Token revocation process completed');
    } catch (e) {
      LoggingService.error('🔑 [OAuth] Error during token revocation: $e');
      // Continue with cleanup even if revocation fails
    }
  }

  /// Clear OAuth-related data
  Future<void> clearOAuthData() async {
    try {
      await secureStorage.delete('oauth_state');
      await secureStorage.delete('oauth_code_verifier');
      await secureStorage.delete('oauth_tokens');
      // NOTE: We intentionally do NOT clear 'last_oauth_callback' here
      // It should persist to prevent reprocessing old callbacks even after logout
      // It's only cleared when starting a NEW OAuth flow in generateAuthorizationUrl()
    } catch (e) {
      LoggingService.debug('Failed to clear OAuth data: $e');
    }
  }
}