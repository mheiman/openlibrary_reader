import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';

/// Settings repository interface
abstract class SettingsRepository {
  /// Get current settings
  Future<Either<Failure, AppSettings>> getSettings();

  /// Update settings
  ///
  /// [settings] - New settings to save
  Future<Either<Failure, void>> updateSettings({
    required AppSettings settings,
  });

  /// Reset settings to defaults
  Future<Either<Failure, void>> resetSettings();
}
