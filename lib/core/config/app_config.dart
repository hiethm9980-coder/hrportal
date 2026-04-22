// ⚠️ BETA LAUNCH CONFIG — No feature changes. Only build/env configuration.

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Centralized app configuration.
///
/// **Default (no `--dart-define`):** always **dev** — uses the fixed local
/// [_devBaseUrl]. Debug, profile, and release builds behave the same unless
/// you pass `FLAVOR`.
///
/// **Production API:** only when you build/run with:
/// `--dart-define=FLAVOR=prod` → then [loadRemoteConfig] reads `base_url` from
/// Firebase Remote Config.
///
/// **Google Play:** store uploads must use `FLAVOR=prod` or the app will keep
/// calling the dev server. See [logPlayStoreBuildHintIfNeeded].
class AppConfig {
  /// Raw compile-time value; empty means “use default dev behavior”.
  static const String _flavorDefine =
      String.fromEnvironment('FLAVOR', defaultValue: '');

  /// `prod` only when explicitly requested; otherwise `dev` (including unknown
  /// values — they fall back to dev).
  static String get flavor => isProduction ? 'prod' : 'dev';

  /// Local dev server URL (fixed; used whenever not in production mode).
  static const String _devBaseUrl = 'http://172.16.0.66:8000';

  /// True only with `--dart-define=FLAVOR=prod`.
  static bool get isProduction => _flavorDefine == 'prod';

  /// API base URL.
  String baseUrl = '';

  /// Whether debug features are enabled.
  final bool enableDebugLogs;

  /// Connection timeout in milliseconds.
  final int connectTimeoutMs;

  /// Receive timeout in milliseconds.
  final int receiveTimeoutMs;

  AppConfig({
    this.enableDebugLogs = false,
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 15000,
  });

  /// Whether base_url has been loaded successfully.
  bool get isReady => baseUrl.isNotEmpty;

  /// Logs a loud reminder when a **release** binary is built without
  /// `FLAVOR=prod` (e.g. before uploading a mistaken build to Google Play).
  static void logPlayStoreBuildHintIfNeeded() {
    if (!kReleaseMode) return;
    if (_flavorDefine == 'prod') return;
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════════════');
    debugPrint('HR Portal: RELEASE build without --dart-define=FLAVOR=prod');
    debugPrint('→ Using DEV fixed base URL ($_devBaseUrl).');
    debugPrint('For Google Play, build with:');
    debugPrint('  flutter build appbundle --release --dart-define=FLAVOR=prod');
    debugPrint('══════════════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// Load base_url based on [isProduction].
  ///
  /// - **dev** (default) → sets [baseUrl] to [_devBaseUrl] immediately.
  /// - **prod** → fetches `base_url` from Firebase Remote Config.
  Future<void> loadRemoteConfig() async {
    if (!isProduction) {
      baseUrl = _devBaseUrl;
      debugPrint('[AppConfig] flavor=dev (define: "$_flavorDefine") → $baseUrl');
      return;
    }

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));

      await remoteConfig.setDefaults({
        'base_url': '',
      });

      final activated = await remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] fetchAndActivate => $activated');
      debugPrint('[RemoteConfig] lastFetchStatus => ${remoteConfig.lastFetchStatus}');
      debugPrint('[RemoteConfig] lastFetchTime => ${remoteConfig.lastFetchTime}');

      final remoteUrl = remoteConfig.getString('base_url');
      debugPrint('[RemoteConfig] base_url value => "$remoteUrl"');

      if (remoteUrl.isNotEmpty) {
        baseUrl = remoteUrl;
      }
      debugPrint('[AppConfig] flavor=prod → baseUrl loaded: ${baseUrl.isNotEmpty}');
    } catch (e, st) {
      debugPrint('[RemoteConfig] ERROR: $e');
      debugPrint('[RemoteConfig] STACK: $st');
    }
  }

  @override
  String toString() =>
      'AppConfig(flavor: $flavor (define: "$_flavorDefine"), baseUrl: $baseUrl)';
}
