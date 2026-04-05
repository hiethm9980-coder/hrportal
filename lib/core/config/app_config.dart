// ⚠️ BETA LAUNCH CONFIG — No feature changes. Only build/env configuration.

/// Application build flavors.
///
/// Each flavor points to a different backend environment.
/// Set via `--dart-define=FLAVOR=xxx` at build time.
enum AppFlavor { dev, staging, prod }

/// Centralized app configuration resolved from build-time constants.
///
/// Usage:
/// ```dart
/// // In main.dart:
/// final config = AppConfig.fromEnvironment();
/// print(config.baseUrl);   // https://staging-api.company.com/api/v1
/// print(config.flavor);    // AppFlavor.staging
/// ```
///
/// Build commands:
/// ```bash
/// # Development
/// flutter run --dart-define=FLAVOR=dev
///
/// # Staging (Internal Beta)
/// flutter run --dart-define=FLAVOR=staging
///
/// # Production
/// flutter run --dart-define=FLAVOR=prod
/// ```
class AppConfig {
  /// Current build flavor.
  final AppFlavor flavor;

  /// API base URL for the current flavor.
  final String baseUrl;

  /// Human-readable environment name (shown in debug UI).
  final String envName;

  /// Whether debug features are enabled.
  final bool enableDebugLogs;

  /// Whether to show environment banner in the app.
  final bool showEnvBanner;

  /// Connection timeout in milliseconds.
  final int connectTimeoutMs;

  /// Receive timeout in milliseconds.
  final int receiveTimeoutMs;

  const AppConfig({
    required this.flavor,
    required this.baseUrl,
    required this.envName,
    required this.enableDebugLogs,
    required this.showEnvBanner,
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 15000,
  });

  /// Resolve configuration from compile-time `--dart-define` constants.
  ///
  /// Defaults to `dev` if no FLAVOR is specified.
  factory AppConfig.fromEnvironment() {
    const flavorStr = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

    switch (flavorStr) {
      case 'prod':
        return const AppConfig(
          flavor: AppFlavor.prod,
          // ── PRODUCTION ─────────────────────────────────
          // TODO: Replace with actual production URL
          baseUrl: 'https://api.company.com/api/v1',
          envName: 'Production',
          enableDebugLogs: false,
          showEnvBanner: false,
          connectTimeoutMs: 15000,
          receiveTimeoutMs: 15000,
        );

      case 'staging':
        return const AppConfig(
          flavor: AppFlavor.staging,
          // ── STAGING (Internal Beta) ────────────────────
          // TODO: Replace with actual staging URL
          baseUrl: 'https://account.alzajeltravel.com/api/v1',
          envName: 'Staging',
          enableDebugLogs: true,
          showEnvBanner: true,
          connectTimeoutMs: 20000,
          receiveTimeoutMs: 20000,
        );

      case 'dev':
      default:
        return const AppConfig(
          flavor: AppFlavor.dev,
          // ── DEVELOPMENT ────────────────────────────────
          baseUrl: 'http://192.168.1.41:8000/api/v1', // Android emulator localhost
          envName: 'Development', 
          enableDebugLogs: true,
          showEnvBanner: true,
          connectTimeoutMs: 30000,
          receiveTimeoutMs: 30000,
        );
    }
  }

  /// Whether this is a production build.
  bool get isProduction => flavor == AppFlavor.prod;

  /// Whether this is a staging (internal beta) build.
  bool get isStaging => flavor == AppFlavor.staging;

  /// Whether this is a development build.
  bool get isDev => flavor == AppFlavor.dev;

  @override
  String toString() => 'AppConfig($envName, $baseUrl)';
}
