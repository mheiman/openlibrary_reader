import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for getting the current logged in user
@lazySingleton
class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  /// Get current logged in user
  ///
  /// Returns [User] if logged in or [Failure] if not logged in or error
  Future<Either<Failure, User>> call() async {
    return await repository.getCurrentUser();
  }
}
