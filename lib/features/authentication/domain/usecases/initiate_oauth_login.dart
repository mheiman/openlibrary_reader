import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for initiating OAuth login
@lazySingleton
class InitiateOAuthLogin {
  final AuthRepository repository;

  InitiateOAuthLogin(this.repository);

  /// Execute the use case
  ///
  /// Returns [String] authorization URL on success or [Failure] on error
  Future<Either<Failure, String>> call() async {
    return await repository.initiateOAuthLogin();
  }
}