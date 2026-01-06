import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Use case for getting app settings
@lazySingleton
class GetSettings {
  final SettingsRepository repository;

  GetSettings(this.repository);

  /// Get current settings
  Future<Either<Failure, AppSettings>> call() async {
    return await repository.getSettings();
  }
}
