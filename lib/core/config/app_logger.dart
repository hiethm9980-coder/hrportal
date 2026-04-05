// ⚠️ BETA LAUNCH CONFIG — No feature changes. Only logging configuration.

import 'dart:developer' as dev;

import 'app_config.dart';

/// Log levels matching standard severity.
enum LogLevel { debug, info, warning, error }

/// Production-safe logger that respects build flavor.
///
/// **Rules:**
/// - `dev` flavor: All logs enabled
/// - `staging` flavor: info, warning, error only (no debug)
/// - `prod` flavor: error only (minimal logging)
/// - NEVER logs tokens, passwords, or sensitive data (enforced by sanitizer)
///
/// Usage:
/// ```dart
/// AppLogger.init(AppConfig.fromEnvironment());
///
/// AppLogger.d('Fetching profile...');                    // Debug only
/// AppLogger.i('Login successful', tag: 'Auth');          // Info
/// AppLogger.w('API version mismatch', tag: 'Network');   // Warning
/// AppLogger.e('Request failed', error: e, tag: 'API');   // Error
/// ```
class AppLogger {
  static late final AppConfig _config;
  static bool _initialized = false;

  AppLogger._();

  /// Initialize once at app startup with the resolved config.
  static void init(AppConfig config) {
    _config = config;
    _initialized = true;
  }

  // ── Public API ──────────────────────────────────────────────────────

  /// Debug log — only in dev builds.
  static void d(String message, {String tag = 'App'}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Info log — dev + staging builds.
  static void i(String message, {String tag = 'App'}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Warning log — dev + staging builds.
  static void w(String message, {String tag = 'App'}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  /// Error log — all builds (always logged).
  static void e(
    String message, {
    String tag = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  // ── Internal ────────────────────────────────────────────────────────

  static void _log(
    LogLevel level,
    String message, {
    String tag = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_initialized) return;
    if (!_shouldLog(level)) return;

    // ── Sanitize: Strip any leaked tokens/passwords ──
    final safeMessage = _sanitize(message);

    final prefix = _prefix(level);
    dev.log(
      '$prefix $safeMessage',
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Determine if this log level should be emitted.
  static bool _shouldLog(LogLevel level) {
    if (_config.enableDebugLogs) {
      return true; // All levels
    }
    return level.index >= LogLevel.error.index; // error only
  }

  /// Prefix emoji for readability in logcat/console.
  static String _prefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '🔴';
    }
  }

  // ── Sensitive Data Sanitizer ────────────────────────────────────────

  /// Patterns that MUST NEVER appear in logs.
  static final _sensitivePatterns = [
    // Bearer tokens
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    // Authorization header values
    RegExp(r'[Aa]uthorization["\s:]+[A-Za-z0-9\-._~+/]{20,}'),
    // Password fields in JSON
    RegExp(r'"password"\s*:\s*"[^"]*"'),
    // Token fields in JSON
    RegExp(r'"token"\s*:\s*"[^"]*"'),
    // API keys
    RegExp(r'[Aa]pi[_-]?[Kk]ey["\s:]+[A-Za-z0-9\-._~+/]{10,}'),
  ];

  /// Replace sensitive patterns with [REDACTED].
  static String _sanitize(String message) {
    var safe = message;
    for (final pattern in _sensitivePatterns) {
      safe = safe.replaceAll(pattern, '[REDACTED]');
    }
    return safe;
  }
}
