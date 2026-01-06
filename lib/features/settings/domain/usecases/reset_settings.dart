import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/settings_repository.dart';

/// Use case for resetting app settings to defaults
@lazySingleton
class ResetSettings {
  final SettingsRepository repository;

  ResetSettings(this.repository);

  /// Reset settings to defaults
  Future<Either<Failure, void>> call() async {
    return await repository.resetSettings();
  }
}
