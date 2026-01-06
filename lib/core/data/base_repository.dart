import 'package:dartz/dartz.dart';

import '../error/exceptions.dart';
import '../error/failures.dart';
import '../services/logging_service.dart';
import '../services/connectivity_service.dart';

/// Base repository class that provides standardized error handling
/// and common utility methods for all repositories.
abstract class BaseRepository {
  /// Execute a repository operation with standardized error handling.
  /// 
  /// [operation] - The async operation to execute
  /// [operationName] - Optional name for logging/debugging purposes
  Future<Either<Failure, T>> execute<T>({
    required Future<T> Function() operation,
    String? operationName,
  }) async {
    try {
      final result = await operation();
      return Right(result);
    } on ServerException catch (e) {
      _logError(operationName, 'ServerException', e);
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      _logError(operationName, 'NetworkException', e);
      return Left(NetworkFailure(e.message));
    } on CacheException catch (e) {
      _logError(operationName, 'CacheException', e);
      return Left(CacheFailure(e.message));
    } on ValidationException catch (e) {
      _logError(operationName, 'ValidationException', e);
      return Left(ValidationFailure(e.message));
    } on UnauthorizedException catch (e) {
      _logError(operationName, 'UnauthorizedException', e);
      return Left(AuthFailure(e.message));
    } on NotFoundException catch (e) {
      _logError(operationName, 'NotFoundException', e);
      return Left(NotFoundFailure(e.message));
    } catch (e, stackTrace) {
      _logError(operationName, 'UnknownException', e, stackTrace);
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Execute a remote operation with optional cache fallback.
  /// 
  /// [remoteOperation] - The primary remote operation to execute
  /// [cacheOperation] - Optional cache operation to try first
  /// [operationName] - Optional name for logging/debugging purposes
  Future<Either<Failure, T>> executeWithCache<T>({
    required Future<T> Function() remoteOperation,
    Future<T> Function()? cacheOperation,
    String? operationName,
  }) async {
    // Try cache first if available
    if (cacheOperation != null) {
      try {
        final cachedResult = await cacheOperation();
        return Right(cachedResult);
      } on CacheException catch (e) {
        _logError(operationName, 'CacheException (fallback to remote)', e);
        // Fall through to remote operation
      } catch (e) {
        _logError(operationName, 'CacheException (fallback to remote)', e);
        // Fall through to remote operation
      }
    }

    // Execute remote operation
    return execute(
      operation: remoteOperation,
      operationName: operationName,
    );
  }

  /// Log errors using the proper logging service.
  void _logError(String? operationName, String exceptionType, dynamic exception, [StackTrace? stackTrace]) {
    LoggingService.error(
      'Repository Error: ${operationName ?? 'Unnamed'} - $exceptionType: $exception',
      exception,
      stackTrace,
    );
  }
}