/// API error codes from the HR Mobile contract v1.0.0 (§9).
///
/// These codes come from the server error envelope:
/// `{ ok: false, code: "...", message: "...", details: {...}, trace_id: "..." }`
class ApiErrorCodes {
  ApiErrorCodes._();

  // ── 401 Authentication ────────────────────────────────────────────
  static const String authRequired = 'AUTH_REQUIRED';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String tokenInvalid = 'TOKEN_INVALID';

  // ── 403 Authorization ─────────────────────────────────────────────
  static const String accessDenied = 'ACCESS_DENIED';
  static const String insufficientPermissions = 'INSUFFICIENT_PERMISSIONS';

  // ── 422 Validation / Business ──────────────────────────────────────
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String businessRuleViolation = 'BUSINESS_RULE_VIOLATION';

  /// Returned when the user tries to mutate `progress_percent` or
  /// `status` on a task that has subtasks — the server now derives these
  /// values automatically and rejects manual writes (HTTP 422).
  static const String parentProgressLocked = 'PARENT_PROGRESS_LOCKED';

  // ── 404 Resource ───────────────────────────────────────────────────
  static const String resourceNotFound = 'RESOURCE_NOT_FOUND';

  // ── 409 Conflict ───────────────────────────────────────────────────
  static const String resourceConflict = 'RESOURCE_CONFLICT';

  // ── 429 Rate Limit ────────────────────────────────────────────────
  static const String rateLimited = 'RATE_LIMITED';

  // ── 500 / 503 Server ──────────────────────────────────────────────
  static const String serverError = 'SERVER_ERROR';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';

  /// Whether this code should force a logout (clear token + redirect).
  ///
  /// The backend uses these codes to indicate the token is no longer valid.
  static bool requiresLogout(String code) {
    return code == tokenExpired || code == tokenInvalid;
  }
}
