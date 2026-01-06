import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// Authentication repository interface
///
/// Defines the contract for authentication operations that must be
/// implemented by the data layer.
abstract class AuthRepository {
  /// Login with username and password
  ///
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> login({
    required String username,
    required String password,
  });

  /// Logout the current user
  ///
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> logout();

  /// Check if user is currently logged in
  ///
  /// [forceCheck] - Force check with server instead of using cached status
  /// Returns [bool] indicating login status or [Failure] on error
  Future<Either<Failure, bool>> isLoggedIn({bool forceCheck = false});

  /// Get current logged in user
  ///
  /// Returns [User] if logged in or [Failure] if not logged in or error
  Future<Either<Failure, User>> getCurrentUser();

  /// Get stored credentials (for auto-login)
  ///
  /// Returns stored credentials or null if none exist
  Future<Either<Failure, Map<String, String>?>> getStoredCredentials();

  /// Clear stored credentials
  ///
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> clearStoredCredentials();

  /// Login with OAuth2
  ///
  /// Initiates OAuth2 login flow and returns authorization URL
  /// Returns [String] authorization URL on success or [Failure] on error
  Future<Either<Failure, String>> initiateOAuthLogin();

  /// Handle OAuth callback
  ///
  /// Handles the OAuth callback with authorization code and state
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> handleOAuthCallback({
    required String code,
    required String state,
  });
}
