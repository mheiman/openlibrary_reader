/// Base exception class
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, [this.statusCode]);

  @override
  String toString() => 'AppException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Server exception - when server returns an error
class ServerException extends AppException {
  const ServerException([String message = 'Server error', int? statusCode])
      : super(message, statusCode);
}

/// Network exception - connection issues
class NetworkException extends AppException {
  const NetworkException([String message = 'Network connection failed'])
      : super(message);
}

/// Cache exception - local storage issues
class CacheException extends AppException {
  const CacheException([String message = 'Cache operation failed'])
      : super(message);
}

/// Authentication exception
class AuthException extends AppException {
  const AuthException([String message = 'Authentication failed', int? statusCode])
      : super(message, statusCode);
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException([String message = 'Validation failed'])
      : super(message);
}

/// Not found exception
class NotFoundException extends AppException {
  const NotFoundException([String message = 'Resource not found'])
      : super(message, 404);
}

/// Unauthorized exception
class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(message, 401);
}
