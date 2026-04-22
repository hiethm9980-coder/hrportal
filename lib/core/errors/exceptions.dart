import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════
// Base
// ═══════════════════════════════════════════════════════════════════

/// Base class for all API exceptions.
///
/// Every exception carries the original [code], human-readable [message],
/// [traceId] for debugging, and optional [details] (e.g. validation errors).
class ApiException extends Equatable implements Exception {
  final String code;
  final String message;
  final String? traceId;
  final Map<String, dynamic>? details;
  final int? statusCode;

  /// Backend-rendered "copy to clipboard" blob. Null means the server
  /// didn't ship one (older endpoints / client-side errors like timeout);
  /// callers should fall back to [message] + [traceId].
  final String? copyText;

  const ApiException({
    required this.code,
    required this.message,
    this.traceId,
    this.details,
    this.statusCode,
    this.copyText,
  });

  /// Validation field errors.
  ///
  /// Handles two backend shapes:
  ///   - **New** (v2): `details.fields = [{name, label, errors: [...]}, ...]`
  ///   - **Legacy**:  `details.errors = {field: [...], ...}`
  ///
  /// Returns `{'field_name': ['Error 1', 'Error 2']}` or empty map.
  Map<String, List<String>> get fieldErrors {
    // New shape first — this is what the current backend returns.
    final fields = details?['fields'];
    if (fields is List) {
      final out = <String, List<String>>{};
      for (final f in fields) {
        if (f is Map) {
          final name = f['name']?.toString();
          final errs = f['errors'];
          if (name != null && errs is List) {
            out[name] = errs.map((e) => e.toString()).toList();
          }
        }
      }
      if (out.isNotEmpty) return out;
    }
    // Legacy fallback.
    final errors = details?['errors'];
    if (errors is Map) {
      return errors.map((key, value) => MapEntry(
            key.toString(),
            (value as List).map((e) => e.toString()).toList(),
          ));
    }
    return {};
  }

  /// Localized field-label lookup — `title → "العنوان"`. Only populated for
  /// the new `details.fields` payload; returns an empty map for the legacy
  /// shape.
  Map<String, String> get fieldLabels {
    final fields = details?['fields'];
    if (fields is List) {
      final out = <String, String>{};
      for (final f in fields) {
        if (f is Map) {
          final name = f['name']?.toString();
          final label = f['label']?.toString();
          if (name != null && label != null && label.isNotEmpty) {
            out[name] = label;
          }
        }
      }
      return out;
    }
    return const {};
  }

  @override
  List<Object?> get props => [code, message, traceId, statusCode];

  @override
  String toString() => 'ApiException($code: $message)';
}

// ═══════════════════════════════════════════════════════════════════
// Authentication (401)
// ═══════════════════════════════════════════════════════════════════

class AuthRequiredException extends ApiException {
  const AuthRequiredException({
    super.message = 'Authentication required.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'AUTH_REQUIRED', statusCode: 401);
}

class TokenExpiredException extends ApiException {
  const TokenExpiredException({
    super.message = 'Token has expired.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'TOKEN_EXPIRED', statusCode: 401);
}

class TokenInvalidException extends ApiException {
  const TokenInvalidException({
    super.message = 'Invalid authentication token.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'TOKEN_INVALID', statusCode: 401);
}

// ═══════════════════════════════════════════════════════════════════
// Authorization (403)
// ═══════════════════════════════════════════════════════════════════

class AccessDeniedException extends ApiException {
  const AccessDeniedException({
    super.message = 'Access denied.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'ACCESS_DENIED', statusCode: 403);
}

class InsufficientPermissionsException extends ApiException {
  const InsufficientPermissionsException({
    super.message = 'Insufficient permissions.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'INSUFFICIENT_PERMISSIONS', statusCode: 403);
}

// ═══════════════════════════════════════════════════════════════════
// Validation (422)
// ═══════════════════════════════════════════════════════════════════

class ValidationException extends ApiException {
  const ValidationException({
    super.message = 'The given data was invalid.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'VALIDATION_FAILED', statusCode: 422);
}

class BusinessRuleException extends ApiException {
  const BusinessRuleException({
    super.message = 'Business rule violation.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'BUSINESS_RULE_VIOLATION', statusCode: 422);
}

// ═══════════════════════════════════════════════════════════════════
// Resource (404)
// ═══════════════════════════════════════════════════════════════════

class ResourceNotFoundException extends ApiException {
  const ResourceNotFoundException({
    super.message = 'The requested resource was not found.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'RESOURCE_NOT_FOUND', statusCode: 404);
}

// ═══════════════════════════════════════════════════════════════════
// Conflict (409)
// ═══════════════════════════════════════════════════════════════════

class ResourceConflictException extends ApiException {
  const ResourceConflictException({
    super.message = 'Resource conflict.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'RESOURCE_CONFLICT', statusCode: 409);
}

// ═══════════════════════════════════════════════════════════════════
// Rate Limit (429)
// ═══════════════════════════════════════════════════════════════════

class RateLimitedException extends ApiException {
  const RateLimitedException({
    super.message = 'Too many requests. Please try again later.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'RATE_LIMITED', statusCode: 429);
}

// ═══════════════════════════════════════════════════════════════════
// Server (500 / 503)
// ═══════════════════════════════════════════════════════════════════

class ServerException extends ApiException {
  const ServerException({
    super.message = 'An internal error occurred.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'SERVER_ERROR', statusCode: 500);
}

class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException({
    super.message = 'Service temporarily unavailable.',
    super.traceId,
    super.details,
    super.copyText,
  }) : super(code: 'SERVICE_UNAVAILABLE', statusCode: 503);
}

// ═══════════════════════════════════════════════════════════════════
// Network (client-side — no API code)
// ═══════════════════════════════════════════════════════════════════

class NetworkException extends ApiException {
  const NetworkException({
    super.message = 'No internet connection.',
  }) : super(code: 'NETWORK_ERROR', statusCode: null);
}

class TimeoutException extends ApiException {
  const TimeoutException({
    super.message = 'Connection timed out.',
  }) : super(code: 'TIMEOUT', statusCode: null);
}
