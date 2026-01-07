import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../error/exceptions.dart';
import '../services/logging_service.dart';
import 'api_constants.dart';

@lazySingleton
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': ApiConstants.contentTypeJson,
          'Accept': ApiConstants.acceptJson,
        },
      ),
    );

    // Custom logging interceptor that only logs JSON responses (not HTML)
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        LoggingService.trace('[DIO] *** Request ***');
        LoggingService.trace('[DIO] uri: ${options.uri}');
        LoggingService.trace('[DIO] method: ${options.method}');
        if (options.data != null) {
          LoggingService.trace('[DIO] data: ${options.data}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        LoggingService.trace('[DIO] *** Response ***');
        LoggingService.trace('[DIO] uri: ${response.requestOptions.uri}');
        LoggingService.trace('[DIO] statusCode: ${response.statusCode}');

        // Only log response body if it's JSON
        final contentType = response.headers.value('content-type');
        if (contentType != null && contentType.contains('application/json')) {
          LoggingService.trace('[DIO] data: ${response.data}');
        } else if (contentType != null && contentType.contains('text/html')) {
          LoggingService.trace('[DIO] data: <HTML content omitted>');
        } else {
          LoggingService.trace('[DIO] data: <Non-JSON content, type: $contentType>');
        }

        handler.next(response);
      },
      onError: (error, handler) {
        LoggingService.error('[DIO] *** DioException ***:');
        LoggingService.error('[DIO] uri: ${error.requestOptions.uri}');
        LoggingService.error('[DIO] statusCode: ${error.response?.statusCode}');

        // Only log error response if it's JSON
        if (error.response != null) {
          final contentType = error.response!.headers.value('content-type');
          if (contentType != null && contentType.contains('application/json')) {
            LoggingService.error('[DIO] data: ${error.response!.data}');
          } else if (contentType != null && contentType.contains('text/html')) {
            LoggingService.error('[DIO] data: <HTML error page omitted>');
          } else {
            LoggingService.error('[DIO] data: <Non-JSON error, type: $contentType>');
          }
        }

        handler.next(error);
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final exception = _handleDioError(error);
        handler.reject(error.copyWith(error: exception));
      },
    ));
  }

  Dio get dio => _dio;

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          'The openlibrary.org server is not responding. Please check the site in your browser or try again later.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data?['message'] ??
            error.response?.statusMessage ??
            'Server error';

        if (statusCode == 401) {
          return UnauthorizedException(message);
        } else if (statusCode == 404) {
          return NotFoundException(message);
        } else if (statusCode != null && statusCode >= 500) {
          return const ServerException(
            'The openlibrary.org server is not responding. Please check the site in your browser or try again later.',
          );
        }
        return ServerException(message, statusCode);

      case DioExceptionType.cancel:
        return const AppException('Request cancelled');

      case DioExceptionType.connectionError:
        return const NetworkException('No internet connection');

      case DioExceptionType.badCertificate:
        return const NetworkException('Certificate verification failed');

      case DioExceptionType.unknown:
        return AppException(
          error.message ?? 'An unknown error occurred',
        );
    }
  }

  /// GET request
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract our custom exception from the error property
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      rethrow;
    }
  }

  /// POST request
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract our custom exception from the error property
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      rethrow;
    }
  }

  /// PUT request
  Future<Response> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract our custom exception from the error property
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      rethrow;
    }
  }

  /// DELETE request
  Future<Response> delete(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract our custom exception from the error property
      if (e.error is AppException) {
        throw e.error as AppException;
      }
      rethrow;
    }
  }
}
