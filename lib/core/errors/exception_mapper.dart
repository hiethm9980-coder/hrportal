import 'api_error_codes.dart';
import 'exceptions.dart';

/// Maps an API error envelope into a typed [ApiException].
///
/// The backend returns a machine-readable `code` plus a human `message`.
/// This mapper converts those codes into Dart exception classes that
/// the UI layer can handle deterministically.
class ExceptionMapper {
  ExceptionMapper._();

  /// Create the correct [ApiException] from an API error.
  ///
  /// [details] is passed-through (e.g. `{fields: [...]}` for validation).
  /// [copyText] is the backend-rendered "copy to clipboard" blob — preserved
  /// verbatim on the exception so the UI can surface a copy button with
  /// zero extra client-side formatting.
  /// [statusCode] is used only for unknown codes.
  static ApiException fromResponse({
    required String code,
    required String message,
    String? traceId,
    Map<String, dynamic>? details,
    String? copyText,
    int? statusCode,
  }) {
    switch (code) {
      // ── 401 Authentication ───────────────────────────────────────
      case ApiErrorCodes.authRequired:
        return AuthRequiredException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      case ApiErrorCodes.tokenExpired:
        return TokenExpiredException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      case ApiErrorCodes.tokenInvalid:
        return TokenInvalidException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 403 Authorization ───────────────────────────────────────
      case ApiErrorCodes.accessDenied:
        return AccessDeniedException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      case ApiErrorCodes.insufficientPermissions:
        return InsufficientPermissionsException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 422 Validation / Business ────────────────────────────────
      case ApiErrorCodes.validationFailed:
        return ValidationException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      case ApiErrorCodes.businessRuleViolation:
        return BusinessRuleException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 404 Resource ─────────────────────────────────────────────
      case ApiErrorCodes.resourceNotFound:
        return ResourceNotFoundException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 409 Conflict ─────────────────────────────────────────────
      case ApiErrorCodes.resourceConflict:
        return ResourceConflictException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 429 Rate Limit ───────────────────────────────────────────
      case ApiErrorCodes.rateLimited:
        return RateLimitedException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── 500 / 503 Server ─────────────────────────────────────────
      case ApiErrorCodes.serverError:
        return ServerException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      case ApiErrorCodes.serviceUnavailable:
        return ServiceUnavailableException(
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
        );

      // ── Unknown / future codes ───────────────────────────────────
      default:
        return ApiException(
          code: code,
          message: message,
          traceId: traceId,
          details: details,
          copyText: copyText,
          statusCode: statusCode,
        );
    }
  }
}
