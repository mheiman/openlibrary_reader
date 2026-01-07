import 'package:logger/logger.dart';

/// Logging service that provides consistent logging throughout the application.
/// 
/// Features:
/// - Multiple log levels (trace, debug, info, warning, error, fatal)
/// - Clean, succinct output without ANSI color codes
/// - Stack trace support for errors
/// - Production-ready logging
class LoggingService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,           // Show 1 method call in stack trace (succinct)
      errorMethodCount: 5,     // Show 5 method calls for errors
      lineLength: 60,         // Line length before wrapping
      colors: false,           // Disable colors to avoid ANSI codes
      printEmojis: false,      // Disable emojis for cleaner output
      dateTimeFormat: DateTimeFormat.none, // Disable timestamps for succinct output
      noBoxingByDefault: true, // Disable boxing by default
    ),
    level: Level.debug,        // Show debug and above in development
    filter: _ProductionFilter(), // Filter out debug/trace in production
  );

  /// Log trace messages (very detailed debugging information)
  static void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log debug messages (debugging information)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log informational messages (general application flow)
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages (potential issues)
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error messages (errors that don't crash the app)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal messages (severe errors that may crash the app)
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

/// Custom filter to handle production vs development logging
class _ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In production, we might want to filter out verbose/debug logs
    // For now, we'll show everything, but this gives us the flexibility
    // to change it later without modifying all logging calls
    return true;
  }
}