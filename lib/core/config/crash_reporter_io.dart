// ⚠️ BETA LAUNCH CONFIG — Monitoring only. No feature changes.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'app_logger.dart';

/// Centralized crash reporting and performance monitoring.
///
/// Wraps Firebase Crashlytics (add `firebase_crashlytics` to pubspec when ready).
/// For now, provides the interface and local fallback logging.
///
/// ## Setup Steps:
/// 1. Add Firebase to android/ios projects via `flutterfire configure`
/// 2. Add `firebase_core` and `firebase_crashlytics` to pubspec.yaml
/// 3. Uncomment the Firebase imports and initialization below
/// 4. Call `CrashReporter.init()` in main.dart before runApp()
///
/// ## Trace ID Correlation:
/// Every crash report includes the last known `X-Trace-Id` from the API.
/// Backend teams can search their logs by this trace ID to correlate
/// mobile crashes with server-side errors.
class CrashReporter {
  static late final AppConfig _config;
  static String? _lastTraceId;
  static bool _initialized = false;

  CrashReporter._();

  /// Initialize crash reporting. Call once in main().
  static Future<void> init(AppConfig config) async {
    _config = config;
    _initialized = true;

    // ── Firebase Crashlytics Setup ──
    // Uncomment after adding firebase_crashlytics:
    //
    // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    //   !config.isDev, // Disabled in dev, enabled in staging + prod
    // );

    // ── Catch Flutter framework errors ──
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      recordFlutterError(details);
    };

    // ── Catch errors outside Flutter (async, isolates) ──
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, reason: 'PlatformDispatcher.onError');
      return true; // Prevent crash
    };

    // ── Catch Isolate errors ──
    Isolate.current.addErrorListener(
      RawReceivePort((pair) async {
        final List<dynamic> errorAndStacktrace = pair;
        await recordError(
          errorAndStacktrace.first,
          errorAndStacktrace.last as StackTrace?,
          reason: 'Isolate.current error',
        );
      }).sendPort,
    );

    AppLogger.i('CrashReporter initialized', tag: 'Crash');
  }

  // ═══════════════════════════════════════════════════════════════════
  // Trace ID Correlation
  // ═══════════════════════════════════════════════════════════════════

  /// Update the last known API trace ID.
  static void setLastTraceId(String traceId) {
    _lastTraceId = traceId;

    // Uncomment after adding firebase_crashlytics:
    // FirebaseCrashlytics.instance.setCustomKey('last_trace_id', traceId);
  }

  /// Set user context for crash reports.
  static void setUser({required int employeeId, int? companyId}) {
    if (!_initialized) return;

    // Uncomment after adding firebase_crashlytics:
    // FirebaseCrashlytics.instance.setUserIdentifier('emp_$employeeId');
    // FirebaseCrashlytics.instance.setCustomKey('company_id', companyId ?? 0);

    AppLogger.i(
      'Crash context set: employee=$employeeId, company=$companyId',
      tag: 'Crash',
    );
  }

  /// Clear user context on logout.
  static void clearUser() {
    if (!_initialized) return;

    // Uncomment after adding firebase_crashlytics:
    // FirebaseCrashlytics.instance.setUserIdentifier('');

    _lastTraceId = null;
    AppLogger.i('Crash context cleared', tag: 'Crash');
  }

  // ═══════════════════════════════════════════════════════════════════
  // Error Recording
  // ═══════════════════════════════════════════════════════════════════

  /// Record a non-fatal error.
  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_initialized) return;

    // Always log locally
    AppLogger.e(
      'Crash: ${reason ?? error.toString()} '
      '[trace: $_lastTraceId]',
      tag: 'Crash',
      error: error,
      stackTrace: stackTrace,
    );

    // Uncomment after adding firebase_crashlytics:
    // await FirebaseCrashlytics.instance.recordError(
    //   error,
    //   stackTrace,
    //   reason: reason,
    //   fatal: fatal,
    //   information: [
    //     if (_lastTraceId != null) 'trace_id: $_lastTraceId',
    //     'flavor: ${_config.envName}',
    //   ],
    // );
  }

  /// Record a Flutter framework error.
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_initialized) return;

    AppLogger.e(
      'FlutterError: ${details.exception} [trace: $_lastTraceId]',
      tag: 'Crash',
      error: details.exception,
      stackTrace: details.stack,
    );

    // Uncomment after adding firebase_crashlytics:
    // await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  /// Log a breadcrumb for crash context.
  static void log(String message) {
    if (!_initialized) return;

    // Uncomment after adding firebase_crashlytics:
    // FirebaseCrashlytics.instance.log(message);

    AppLogger.d(message, tag: 'Breadcrumb');
  }
}
