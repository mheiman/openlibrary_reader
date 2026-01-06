import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for logging out the current user
@lazySingleton
class Logout {
  final AuthRepository repository;

  Logout(this.repository);

  /// Execute logout
  ///
  /// Returns success or [Failure] on error
  Future<Either<Failure, void>> call() async {
    return await repository.logout();
  }
}
