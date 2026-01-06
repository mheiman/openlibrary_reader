import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Use case for updating app settings
@lazySingleton
class UpdateSettings {
  final SettingsRepository repository;

  UpdateSettings(this.repository);

  /// Update settings
  Future<Either<Failure, void>> call({
    required AppSettings settings,
  }) async {
    return await repository.updateSettings(settings: settings);
  }
}
