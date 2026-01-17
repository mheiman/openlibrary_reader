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
  const ServerException([super.message = 'Server error', super.statusCode]);
}

/// Network exception - connection issues
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network connection failed']);
}

/// Cache exception - local storage issues
class CacheException extends AppException {
  const CacheException([super.message = 'Cache operation failed']);
}

/// Authentication exception
class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed', super.statusCode]);
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException([super.message = 'Validation failed']);
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
