import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Implementation of settings repository
@LazySingleton(as: SettingsRepository)
class SettingsRepositoryImpl extends BaseRepository implements SettingsRepository {
  final PreferencesService preferencesService;

  SettingsRepositoryImpl(this.preferencesService);

  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    try {
      final moveToReading = preferencesService.getBool(
            ApiConstants.prefMoveToReading,
          ) ??
          false;

      final showChrome = preferencesService.getBool(
            ApiConstants.prefShowChrome,
          ) ??
          false;

      final keepAwake = preferencesService.getBool(
            ApiConstants.prefKeepAwake,
          ) ??
          true;

      final coverWidth = preferencesService.getDouble(
            ApiConstants.prefCoverSize,
          ) ??
          AppSettings.defaultCoverWidth;

      final sortOrder = preferencesService.getString(
            ApiConstants.prefSortOrder,
          ) ??
          'dateAdded';

      final visibleShelves = preferencesService.getStringList(
            ApiConstants.prefShelfVisibility,
          ) ??
          [];

      final searchSortOrder = preferencesService.getString(
            ApiConstants.prefSearchSortOrder,
          ) ??
          'datePublished';

      final searchSortAscending = preferencesService.getBool(
            ApiConstants.prefSearchSortAscending,
          ) ??
          true;

      final showLists = preferencesService.getBool(
            ApiConstants.prefShowLists,
          ) ??
          false;

      final darkMode = preferencesService.getString(
            ApiConstants.prefDarkMode,
          ) ??
          AppSettings.darkModeOff;

      final settings = AppSettings(
        moveToReading: moveToReading,
        showChrome: showChrome,
        keepAwake: keepAwake,
        coverWidth: coverWidth,
        sortOrder: sortOrder,
        visibleShelves: visibleShelves,
        searchSortOrder: searchSortOrder,
        searchSortAscending: searchSortAscending,
        showLists: showLists,
        darkMode: darkMode,
      );

      return Right(settings);
    } catch (e) {
      return Left(CacheFailure('Failed to get settings: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSettings({
    required AppSettings settings,
  }) async {
    try {
      await preferencesService.setBool(
        ApiConstants.prefMoveToReading,
        settings.moveToReading,
      );

      await preferencesService.setBool(
        ApiConstants.prefShowChrome,
        settings.showChrome,
      );

      await preferencesService.setBool(
        ApiConstants.prefKeepAwake,
        settings.keepAwake,
      );

      await preferencesService.setDouble(
        ApiConstants.prefCoverSize,
        settings.coverWidth,
      );

      await preferencesService.setString(
        ApiConstants.prefSortOrder,
        settings.sortOrder,
      );

      await preferencesService.setStringList(
        ApiConstants.prefShelfVisibility,
        settings.visibleShelves,
      );

      await preferencesService.setString(
        ApiConstants.prefSearchSortOrder,
        settings.searchSortOrder,
      );

      await preferencesService.setBool(
        ApiConstants.prefSearchSortAscending,
        settings.searchSortAscending,
      );

      await preferencesService.setBool(
        ApiConstants.prefShowLists,
        settings.showLists,
      );

      await preferencesService.setString(
        ApiConstants.prefDarkMode,
        settings.darkMode,
      );

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to update settings: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> resetSettings() async {
    try {
      await preferencesService.remove(ApiConstants.prefMoveToReading);
      await preferencesService.remove(ApiConstants.prefShowChrome);
      await preferencesService.remove(ApiConstants.prefKeepAwake);
      await preferencesService.remove(ApiConstants.prefCoverSize);
      await preferencesService.remove(ApiConstants.prefSortOrder);
      await preferencesService.remove(ApiConstants.prefShelfVisibility);
      await preferencesService.remove(ApiConstants.prefSearchSortOrder);
      await preferencesService.remove(ApiConstants.prefSearchSortAscending);
      await preferencesService.remove(ApiConstants.prefShowLists);
      await preferencesService.remove(ApiConstants.prefDarkMode);

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to reset settings: ${e.toString()}'));
    }
  }
}
