import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../errors/exception_mapper.dart';
import '../errors/exceptions.dart';
import '../storage/secure_token_storage.dart';
import 'auth_interceptor.dart';
import 'base_response.dart';
import 'session_manager.dart';

/// Configured HTTP client for the HR Mobile API.
///
/// All feature repositories use this client. It:
/// - Points to `ApiConstants.baseUrl`
/// - Attaches Bearer token via [AuthInterceptor]
/// - Parses every response into [BaseResponse<T>]
/// - Converts API error codes into typed Dart exceptions
///
/// Usage:
/// ```dart
/// final client = ApiClient(storage: storage, sessionManager: manager);
/// final response = await client.get<EmployeeProfile>(
///   ApiConstants.profile,
///   fromJson: (json) => EmployeeProfile.fromJson(json),
/// );
/// ```
class ApiClient {
  late final Dio _dio;
  final SessionManager sessionManager;

  ApiClient({
    required SecureTokenStorage storage,
    required this.sessionManager,
    Dio? dio,
  }) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout:
                const Duration(milliseconds: ApiConstants.connectTimeout),
            receiveTimeout:
                const Duration(milliseconds: ApiConstants.receiveTimeout),
            sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            validateStatus: (_) {
              return true;
            }, // Let us handle all status codes.
          ),
        );

    _dio.interceptors.add(
      AuthInterceptor(storage: storage, sessionManager: sessionManager),
    );

    // ── Debug Logger ──
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('┌── REQUEST ──────────────────────────────────');
          debugPrint('│ ${options.method} ${options.baseUrl}${options.path}');
          if (options.queryParameters.isNotEmpty) {
            debugPrint('│ Query: ${options.queryParameters}');
          }
          if (options.data != null) {
            debugPrint('│ Body: ${options.data}');
          }
          debugPrint('│ Headers: ${options.headers}');
          debugPrint('└─────────────────────────────────────────────');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('┌── RESPONSE ─────────────────────────────────');
          debugPrint('│ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}');
          debugPrint('│ Data: ${response.data}');
          debugPrint('└─────────────────────────────────────────────');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('┌── ERROR ────────────────────────────────────');
          debugPrint('│ ${error.requestOptions.method} ${error.requestOptions.path}');
          debugPrint('│ Type: ${error.type}');
          debugPrint('│ Message: ${error.message}');
          if (error.response != null) {
            debugPrint('│ Status: ${error.response?.statusCode}');
            debugPrint('│ Data: ${error.response?.data}');
          }
          debugPrint('└─────────────────────────────────────────────');
          handler.next(error);
        },
      ),
    );
  }

  /// Expose Dio for testing or advanced usage.
  Dio get dio => _dio;

  // ═══════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════

  /// HTTP GET that returns parsed [BaseResponse<T>].
  Future<BaseResponse<T>> get<T>(
    String path, {
    T Function(Object? json)? fromJson,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _execute<T>(
      () => _dio.get(path, queryParameters: queryParameters),
      fromJson: fromJson,
    );
    return response;
  }

  /// HTTP POST that returns parsed [BaseResponse<T>].
  Future<BaseResponse<T>> post<T>(
    String path, {
    T Function(Object? json)? fromJson,
    Object? data,
  }) async {
    final response = await _execute<T>(
      () => _dio.post(path, data: data),
      fromJson: fromJson,
    );
    return response;
  }

  /// HTTP PUT that returns parsed [BaseResponse<T>].
  Future<BaseResponse<T>> put<T>(
    String path, {
    T Function(Object? json)? fromJson,
    Map<String, dynamic>? data,
  }) async {
    final response = await _execute<T>(
      () => _dio.put(path, data: data),
      fromJson: fromJson,
    );
    return response;
  }

  /// HTTP PATCH that returns parsed [BaseResponse<T>].
  Future<BaseResponse<T>> patch<T>(
    String path, {
    T Function(Object? json)? fromJson,
    Object? data,
  }) async {
    final response = await _execute<T>(
      () => _dio.patch(path, data: data),
      fromJson: fromJson,
    );
    return response;
  }

  /// HTTP DELETE that returns parsed [BaseResponse<T>].
  Future<BaseResponse<T>> delete<T>(
    String path, {
    T Function(Object? json)? fromJson,
  }) async {
    final response = await _execute<T>(
      () => _dio.delete(path),
      fromJson: fromJson,
    );
    return response;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Core Execution
  // ═══════════════════════════════════════════════════════════════════

  Future<BaseResponse<T>> _execute<T>(
    Future<Response> Function() request, {
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await request();
      final json = response.data;

      if (json is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected response format from server.',
        );
      }

      final baseResponse = BaseResponse<T>.fromJson(json, fromJson);

      // If the response is an error, throw the mapped exception.
      if (baseResponse.isError) {
        final code = baseResponse.code;

        // ✅ IMPORTANT:
        // Because validateStatus always returns true, Dio will NOT throw on 401/403,
        // so AuthInterceptor.onError may never run.
        // Therefore, handle forced logout here based on API error codes.
        if (code != null && _requiresReauth(code)) {
          try {
            await sessionManager.onTokenExpired();
          } catch (_) {
            // Do not let logout errors hide the original API error.
          }
        }

        if (code != null) {
          throw ExceptionMapper.fromResponse(
            code: code,
            message: baseResponse.message,
            traceId: baseResponse.traceId,
            details: baseResponse.details,
            statusCode: response.statusCode,
          );
        }

        // Fallback if server marked error without a code.
        throw ServerException(
          message: baseResponse.message ?? 'Unknown server error.',
        );
      }

      return baseResponse;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      // On Web, low-level socket errors are surfaced differently.
      // On IO platforms, some adapters may still throw non-Dio exceptions.
      // We keep this as a safe fallback.
      throw ServerException(message: 'Unexpected error: ${e.toString()}');
    }
  }

  /// Map Dio-level errors to our exception hierarchy.
  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        // Try to parse the error body.
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data.containsKey('code')) {
          return ExceptionMapper.fromResponse(
            code: data['code'] as String,
            message: data['message'] as String? ?? 'Unknown error',
            traceId: data['trace_id'] as String?,
            details: data['details'] is Map
                ? Map<String, dynamic>.from(data['details'] as Map)
                : null,
            statusCode: e.response?.statusCode,
          );
        }
        return ServerException(
          message: 'Server error: ${e.response?.statusCode}',
        );
      default:
        return const ServerException(
          message: 'An unexpected network error occurred.',
        );
    }
  }

  /// API error codes that must force logout / re-auth.
  bool _requiresReauth(String code) {
    switch (code) {
      case 'TOKEN_EXPIRED':
      case 'TOKEN_INVALID':
      case 'UNAUTHENTICATED':
        return true;
      default:
        return false;
    }
  }
}