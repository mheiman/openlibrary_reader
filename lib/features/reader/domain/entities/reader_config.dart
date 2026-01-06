import 'package:equatable/equatable.dart';

/// Reader configuration
class ReaderConfig extends Equatable {
  final String bookId; // Edition ID or Archive.org identifier
  final String workId;
  final String title;
  final bool showChrome; // Show time/battery
  final bool keepAwake; // Keep screen awake
  final bool fullScreen; // Full-screen mode
  final String? loanType; // '1hour' or '14day'
  final DateTime? loanExpiry;

  const ReaderConfig({
    required this.bookId,
    required this.workId,
    required this.title,
    this.showChrome = false,
    this.keepAwake = false,
    this.fullScreen = true,
    this.loanType,
    this.loanExpiry,
  });

  @override
  List<Object?> get props => [
        bookId,
        workId,
        title,
        showChrome,
        keepAwake,
        fullScreen,
        loanType,
        loanExpiry,
      ];

  /// Check if loan is still valid
  bool get isLoanValid {
    if (loanExpiry == null) return false;
    return DateTime.now().isBefore(loanExpiry!);
  }

  /// Get remaining loan time in minutes
  int get remainingMinutes {
    if (loanExpiry == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(loanExpiry!)) return 0;
    return loanExpiry!.difference(now).inMinutes;
  }

  /// Copy with updated fields
  ReaderConfig copyWith({
    String? bookId,
    String? workId,
    String? title,
    bool? showChrome,
    bool? keepAwake,
    bool? fullScreen,
    String? loanType,
    DateTime? loanExpiry,
  }) {
    return ReaderConfig(
      bookId: bookId ?? this.bookId,
      workId: workId ?? this.workId,
      title: title ?? this.title,
      showChrome: showChrome ?? this.showChrome,
      keepAwake: keepAwake ?? this.keepAwake,
      fullScreen: fullScreen ?? this.fullScreen,
      loanType: loanType ?? this.loanType,
      loanExpiry: loanExpiry ?? this.loanExpiry,
    );
  }
}
