// ⚠️ BETA LAUNCH CONFIG — No feature changes. Only build/env configuration.

import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Centralized app configuration — relies on Firebase Remote Config only.
///
/// - base_url is fetched from Firebase Remote Config at login time.
/// - If offline at login: base_url stays empty, user sees error.
/// - Once fetched, base_url stays in memory for the app session.
class AppConfig {
  /// API base URL — fetched from Firebase Remote Config.
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

  /// Fetch base_url from Firebase Remote Config.
  /// If offline, baseUrl stays empty.
  Future<void> loadRemoteConfig() async {
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
  String toString() => 'AppConfig(baseUrl: $baseUrl)';
}
