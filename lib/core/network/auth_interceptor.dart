import 'package:dio/dio.dart';

import '../config/app_logger.dart';
import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';
import 'session_manager.dart';

/// Dio interceptor that handles:
///
/// 1. **Request:** Attaches `Bearer {token}` and `Accept: application/json`.
/// 2. **Response:** Reads `X-API-Version` and `X-Trace-Id` headers.
/// 3. **Error:** Detects `TOKEN_EXPIRED` / `TOKEN_INVALID` → triggers auto-logout.
class AuthInterceptor extends Interceptor {
  final SecureTokenStorage _storage;
  final SessionManager _sessionManager;

  AuthInterceptor({
    required SecureTokenStorage storage,
    required SessionManager sessionManager,
  })  : _storage = storage,
        _sessionManager = sessionManager;

  // ── Request ─────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Always send Accept header.
    options.headers['Accept'] = 'application/json';

    // Attach Bearer token if available (skip for login).
    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  // ── Response ────────────────────────────────────────────────────────

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Log API version for debugging / version mismatch detection.
    final apiVersion = response.headers.value(ApiConstants.versionHeader);
    final traceId = response.headers.value(ApiConstants.traceIdHeader);

    if (apiVersion != null && apiVersion != ApiConstants.contractVersion) {
      AppLogger.w(
        'API version mismatch! Expected ${ApiConstants.contractVersion}, '
        'got $apiVersion. Trace: $traceId',
        tag: 'Network',
      );
    }

    handler.next(response);
  }

  // ── Error ───────────────────────────────────────────────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (response != null && response.statusCode == 401) {
      AppLogger.w(
        '401 Unauthorized. Triggering auto-logout.',
        tag: 'Auth',
      );
      await _sessionManager.onTokenExpired();
    }

    handler.next(err);
  }
}
