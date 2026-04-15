// ⚠️ API CONTRACT v1.0.0 — Envelope structure matches §1 exactly.
// Success: { ok, message, data, trace_id }
// Error:   { ok, code, message, details, trace_id }

/// Generic wrapper for all API responses.
///
/// The API always returns one of two envelopes:
/// - **Success:** `ok=true`, `data` contains the payload, `code` is null.
/// - **Error:** `ok=false`, `code` contains the error code, `data` is null.
///
/// Usage:
/// ```dart
/// final response = BaseResponse<EmployeeProfile>.fromJson(
///   json,
///   (data) => EmployeeProfile.fromJson(data as Map<String, dynamic>),
/// );
/// if (response.isSuccess) {
///   debugPrint(response.data!.name);
/// }
/// ```
class BaseResponse<T> {
  /// Whether the request succeeded.
  final bool ok;

  /// Human-readable message from the server.
  final String message;

  /// Parsed payload (null for errors or empty-body success).
  final T? data;

  /// UUID v4 request trace identifier.
  final String traceId;

  /// Machine-readable error code (null for success).
  final String? code;

  /// Extra error context (e.g. validation errors). Null for success.
  final Map<String, dynamic>? details;

  const BaseResponse({
    required this.ok,
    required this.message,
    this.data,
    required this.traceId,
    this.code,
    this.details,
  });

  /// Whether the response is a success.
  bool get isSuccess => ok;

  /// Whether the response is an error.
  bool get isError => !ok;

  /// Convenience: validation field errors map.
  ///
  /// Returns `{'field': ['error1', 'error2']}` or empty map.
  Map<String, List<String>> get fieldErrors {
    final errors = details?['errors'];
    if (errors is Map) {
      return errors.map((key, value) => MapEntry(
            key.toString(),
            (value as List).map((e) => e.toString()).toList(),
          ));
    }
    return {};
  }

  /// Parse from raw JSON map.
  ///
  /// [fromJsonT] converts the `data` field into type [T].
  /// Pass `null` if no data parsing is needed (e.g. logout returns null data).
  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    final ok = json['ok'] as bool;
    final message = json['message'] as String? ?? '';
    final traceId = json['trace_id'] as String? ?? '';

    if (ok) {
      // ── Success envelope ──
      return BaseResponse<T>(
        ok: true,
        message: message,
        data: json['data'] != null && fromJsonT != null
            ? fromJsonT(json['data'])
            : null,
        traceId: traceId,
      );
    } else {
      // ── Error envelope ──
      return BaseResponse<T>(
        ok: false,
        message: message,
        traceId: traceId,
        code: json['code'] as String?,
        details: json['details'] is Map
            ? Map<String, dynamic>.from(json['details'] as Map)
            : null,
      );
    }
  }
}
