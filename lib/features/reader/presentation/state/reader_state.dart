import 'package:equatable/equatable.dart';

import '../../domain/entities/reader_config.dart';

/// Reader state
abstract class ReaderState extends Equatable {
  const ReaderState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ReaderInitial extends ReaderState {
  const ReaderInitial();
}

/// Loading state
class ReaderLoading extends ReaderState {
  const ReaderLoading();
}

/// Ready to read state
class ReaderReady extends ReaderState {
  final String readerUrl;
  final ReaderConfig config;

  const ReaderReady({
    required this.readerUrl,
    required this.config,
  });

  @override
  List<Object?> get props => [readerUrl, config];
}

/// Error state
class ReaderError extends ReaderState {
  final String message;

  const ReaderError(this.message);

  @override
  List<Object?> get props => [message];
}
