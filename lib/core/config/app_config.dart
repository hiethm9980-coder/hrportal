// ⚠️ BETA LAUNCH CONFIG — No feature changes. Only build/env configuration.

import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Centralized app configuration.
///
/// - Reads FLAVOR from --dart-define (defaults to 'dev').
/// - dev  → uses local dev URL directly, no Firebase needed.
/// - prod → fetches base_url from Firebase Remote Config.
class AppConfig {
  /// The current flavor: 'dev' or 'prod'.
  /// Set at compile time via: --dart-define=FLAVOR=prod
  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// Local dev server URL.
  static const String _devBaseUrl = 'http://192.168.1.41:8000';

  /// Whether we are running in production mode.
  static bool get isProduction => flavor == 'prod';

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

  /// Load base_url based on the current flavor.
  ///
  /// - dev  → sets baseUrl to the local dev URL immediately.
  /// - prod → fetches from Firebase Remote Config.
  Future<void> loadRemoteConfig() async {
    if (!isProduction) {
      // Dev mode: use local URL directly.
      baseUrl = _devBaseUrl;
      // ignore: avoid_print
      print('[AppConfig] FLAVOR=dev → using local URL: $baseUrl');
      return;
    }

    // Production mode: fetch from Firebase Remote Config.
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
      // ignore: avoid_print
      print('[RemoteConfig] fetchAndActivate => $activated');
      // ignore: avoid_print
      print('[RemoteConfig] lastFetchStatus => ${remoteConfig.lastFetchStatus}');
      // ignore: avoid_print
      print('[RemoteConfig] lastFetchTime => ${remoteConfig.lastFetchTime}');

      final remoteUrl = remoteConfig.getString('base_url');
      // ignore: avoid_print
      print('[RemoteConfig] base_url value => "$remoteUrl"');

      if (remoteUrl.isNotEmpty) {
        baseUrl = remoteUrl;
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[RemoteConfig] ERROR: $e');
      // ignore: avoid_print
      print('[RemoteConfig] STACK: $st');
    }
  }

  @override
  String toString() =>
      'AppConfig(flavor: $flavor, baseUrl: $baseUrl)';
}
