import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/reset_settings.dart';
import '../../domain/usecases/update_settings.dart';
import 'settings_state.dart';

/// Settings state notifier
@lazySingleton
class SettingsNotifier extends ChangeNotifier {
  final GetSettings getSettings;
  final UpdateSettings updateSettings;
  final ResetSettings resetSettings;

  SettingsNotifier({
    required this.getSettings,
    required this.updateSettings,
    required this.resetSettings,
  });

  SettingsState _state = const SettingsInitial();

  SettingsState get state => _state;

  void _setState(SettingsState state) {
    _state = state;
    notifyListeners();
  }

  /// Load settings
  Future<void> loadSettings() async {
    _setState(const SettingsLoading());

    final result = await getSettings();

    result.fold(
      (failure) => _setState(SettingsError(failure.message)),
      (settings) => _setState(SettingsLoaded(settings)),
    );
  }

  /// Update a specific setting
  Future<void> updateSetting(AppSettings settings) async {
    final result = await updateSettings(settings: settings);

    result.fold(
      (failure) => _setState(SettingsError(failure.message)),
      (_) => _setState(SettingsLoaded(settings)),
    );
  }

  /// Reset to defaults
  Future<void> reset() async {
    final result = await resetSettings();

    result.fold(
      (failure) => _setState(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }
}
