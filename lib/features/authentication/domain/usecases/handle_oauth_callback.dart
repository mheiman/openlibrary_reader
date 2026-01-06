import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for handling OAuth callback
@lazySingleton
class HandleOAuthCallback {
  final AuthRepository repository;

  HandleOAuthCallback(this.repository);

  /// Execute the use case
  ///
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> call({
    required String code,
    required String state,
  }) async {
    return await repository.handleOAuthCallback(code: code, state: state);
  }
}