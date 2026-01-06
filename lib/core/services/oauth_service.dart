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
      
      final response = await dioClient.post(
        '${ApiConstants.openLibraryBaseUrl}${ApiConstants.oauthTokenPath}',
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': ApiConstants.oauthRedirectUri,
          'client_id': ApiConstants.oauthClientId,
          'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      
      LoggingService.debug('🔑 [OAuth] Token exchange response status: ${response.statusCode}');
      LoggingService.debug('🔑 [OAuth] Token exchange response data: ${response.data}');
      
      if (response.statusCode == 200) {
        LoggingService.debug('🔑 [OAuth] Token exchange successful!');
        return response.data as Map<String, dynamic>;
      } else {
        LoggingService.error('🔑 [OAuth] Token exchange failed with status ${response.statusCode}: ${response.statusMessage}');
        throw AuthException('Token exchange failed: ${response.statusMessage}', response.statusCode);
      }
    } on DioException catch (e) {
      LoggingService.error('🔑 [OAuth] DioException during token exchange: ${e.message}');
      if (e.response?.statusCode == 400) {
        LoggingService.error('🔑 [OAuth] Invalid authorization code: ${e.response?.data?['error_description']}');
        throw AuthException('Invalid authorization code: ${e.response?.data?['error_description']}', 400);
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
        LoggingService.debug('Failed to save OAuth cookie: $e');
      }
    }
  }

  /// Clear OAuth-related data
  Future<void> clearOAuthData() async {
    try {
      await secureStorage.delete('oauth_state');
      await secureStorage.delete('oauth_code_verifier');
      await secureStorage.delete('oauth_tokens');
    } catch (e) {
      LoggingService.debug('Failed to clear OAuth data: $e');
    }
  }
}