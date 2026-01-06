import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/oauth_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

/// Implementation of [AuthRepository]
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl extends BaseRepository implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final OAuthService oauthService;

  AuthRepositoryImpl(this.remoteDataSource, this.oauthService);

  @override
  Future<Either<Failure, User>> login({
    required String username,
    required String password,
  }) async {
    return execute(
      operation: () async {
        final userModel = await remoteDataSource.login(
          username: username,
          password: password,
        );
        return userModel.toEntity();
      },
      operationName: 'login',
    );
  }

  @override
  Future<Either<Failure, void>> logout() async {
    return execute(
      operation: () async {
        await remoteDataSource.logout();
        return;
      },
      operationName: 'logout',
    );
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn({bool forceCheck = false}) async {
    return execute(
      operation: () async {
        final isLoggedIn = await remoteDataSource.isLoggedIn(
          forceCheck: forceCheck,
        );
        return isLoggedIn;
      },
      operationName: 'isLoggedIn',
    );
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    return execute(
      operation: () async {
        final userModel = await remoteDataSource.getCurrentUser();
        return userModel.toEntity();
      },
      operationName: 'getCurrentUser',
    );
  }

  @override
  Future<Either<Failure, Map<String, String>?>> getStoredCredentials() async {
    return execute(
      operation: () async {
        final credentials = await remoteDataSource.getStoredCredentials();
        return credentials;
      },
      operationName: 'getStoredCredentials',
    );
  }

  @override
  Future<Either<Failure, void>> clearStoredCredentials() async {
    return execute(
      operation: () async {
        await remoteDataSource.logout(); // This clears credentials
        return;
      },
      operationName: 'clearStoredCredentials',
    );
  }

  @override
  Future<Either<Failure, String>> initiateOAuthLogin() async {
    return execute(
      operation: () async {
        final authUrl = await oauthService.generateAuthorizationUrl();
        return authUrl;
      },
      operationName: 'initiateOAuthLogin',
    );
  }

  @override
  Future<Either<Failure, User>> handleOAuthCallback({
    required String code,
    required String state,
  }) async {
    return execute(
      operation: () async {
        // Exchange code for tokens
        final tokens = await oauthService.exchangeCodeForTokens(code, state);
        final accessToken = tokens['access_token'] as String;
        
        // Exchange tokens for session cookie
        await oauthService.exchangeTokensForCookie(accessToken);
        
        // Get user info
        final userInfo = await oauthService.getUserInfo(accessToken);
        
        // Store user info in secure storage for auto-login
        final username = userInfo['username'] as String? ?? userInfo['sub'] as String? ?? '';
        await remoteDataSource.secureStorage.write('username', username);
        
        // Create and return user model
        return UserModel(
          userId: userInfo['sub'] as String? ?? '',
          username: username,
          displayName: userInfo['displayname'] as String? ?? username,
        ).toEntity();
      },
      operationName: 'handleOAuthCallback',
    );
  }
}
