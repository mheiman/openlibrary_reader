import 'package:equatable/equatable.dart';

/// Base class for all failures
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred']) : super(message);
}

/// Network/Connection failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error occurred']) : super(message);
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred']) : super(message);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication failed']) : super(message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Validation failed']) : super(message);
}

/// Not found failures
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found']) : super(message);
}

/// Unauthorized failures
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Unauthorized access']) : super(message);
}

/// Unknown/Unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unknown error occurred']) : super(message);
}
