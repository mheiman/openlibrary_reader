import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for logging in a user
@lazySingleton
class Login {
  final AuthRepository repository;

  Login(this.repository);

  /// Execute login with username and password
  ///
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> call({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty) {
      return const Left(ValidationFailure('Username cannot be empty'));
    }
    if (password.isEmpty) {
      return const Left(ValidationFailure('Password cannot be empty'));
    }

    return await repository.login(username: username, password: password);
  }
}
