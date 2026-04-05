// ⚠️ BETA LAUNCH CONFIG — Monitoring only. No feature changes.
//
// Web build notes:
// - `dart:isolate` is not available on Web, so we omit isolate error listeners.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'app_logger.dart';

/// Web-safe crash reporter implementation.
///
/// Keeps the same API as the mobile/desktop implementation, but without
/// isolate-specific hooks.
class CrashReporter {
  static late final AppConfig _config;
  static String? _lastTraceId;
  static bool _initialized = false;

  CrashReporter._();

  static Future<void> init(AppConfig config) async {
    _config = config;
    _initialized = true;

    // ── Catch Flutter framework errors ──
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      recordFlutterError(details);
    };

    // ── Catch errors outside Flutter (async) ──
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, reason: 'PlatformDispatcher.onError');
      return true;
    };

    AppLogger.i('CrashReporter initialized (WEB)', tag: 'Crash');
  }

  // ═══════════════════════════════════════════════════════════════════
  // Trace ID Correlation
  // ═══════════════════════════════════════════════════════════════════

  static void setLastTraceId(String traceId) {
    _lastTraceId = traceId;
  }

  static void setUser({required int employeeId, int? companyId}) {
    if (!_initialized) return;

    AppLogger.i(
      'Crash context set: employee=$employeeId, company=$companyId',
      tag: 'Crash',
    );
  }

  static void clearUser() {
    if (!_initialized) return;
    _lastTraceId = null;
    AppLogger.i('Crash context cleared', tag: 'Crash');
  }

  // ═══════════════════════════════════════════════════════════════════
  // Error Recording
  // ═══════════════════════════════════════════════════════════════════

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_initialized) return;

    AppLogger.e(
      'Crash: ${reason ?? error.toString()} [trace: $_lastTraceId]',
      tag: 'Crash',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_initialized) return;

    AppLogger.e(
      'FlutterError: ${details.exception} [trace: $_lastTraceId]',
      tag: 'Crash',
      error: details.exception,
      stackTrace: details.stack,
    );
  }

  static void log(String message) {
    if (!_initialized) return;
    AppLogger.d(message, tag: 'Breadcrumb');
  }
}
