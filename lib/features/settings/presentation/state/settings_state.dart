import '../../domain/entities/app_settings.dart';

/// Base settings state
abstract class SettingsState {
  const SettingsState();
}

/// Initial state
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Loading state
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Settings loaded state
class SettingsLoaded extends SettingsState {
  final AppSettings settings;

  const SettingsLoaded(this.settings);
}

/// Settings error state
class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);
}
