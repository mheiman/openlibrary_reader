import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for checking if user is logged in
@lazySingleton
class CheckLoginStatus {
  final AuthRepository repository;

  CheckLoginStatus(this.repository);

  /// Check if user is logged in
  ///
  /// [forceCheck] - Force check with server instead of using cached status
  /// Returns [bool] indicating login status or [Failure] on error
  Future<Either<Failure, bool>> call({bool forceCheck = false}) async {
    return await repository.isLoggedIn(forceCheck: forceCheck);
  }
}
