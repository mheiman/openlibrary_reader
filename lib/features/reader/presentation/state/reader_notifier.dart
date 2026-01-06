import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../settings/domain/usecases/get_settings.dart';
import '../../domain/entities/reader_config.dart';
import '../../domain/usecases/get_reader_url.dart';
import 'reader_state.dart';

/// Reader state notifier
@injectable
class ReaderNotifier extends ChangeNotifier {
  final GetReaderUrl getReaderUrlUseCase;
  final GetSettings getSettingsUseCase;

  ReaderState _state = const ReaderInitial();
  ReaderState get state => _state;

  ReaderNotifier({
    required this.getReaderUrlUseCase,
    required this.getSettingsUseCase,
  });

  /// Update state and notify listeners
  void _emit(ReaderState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Initialize reader
  Future<void> initializeReader({
    required String bookId,
    required String workId,
    required String title,
  }) async {
    _emit(const ReaderLoading());

    // Get settings from centralized AppSettings
    final settingsResult = await getSettingsUseCase();
    final showChrome = settingsResult.fold(
      (_) => false, // Default if settings fail to load
      (settings) => settings.showChrome,
    );
    final keepAwake = settingsResult.fold(
      (_) => true, // Default if settings fail to load
      (settings) => settings.keepAwake,
    );

    // Get reader URL
    final result = await getReaderUrlUseCase(bookId: bookId);

    result.fold(
      (failure) => _emit(ReaderError(failure.message)),
      (url) {
        final config = ReaderConfig(
          bookId: bookId,
          workId: workId,
          title: title,
          showChrome: showChrome,
          keepAwake: keepAwake,
        );

        _emit(ReaderReady(
          readerUrl: url,
          config: config,
        ));
      },
    );
  }
}
