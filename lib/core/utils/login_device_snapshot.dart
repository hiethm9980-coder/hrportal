import 'dart:convert';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:package_info_plus/package_info_plus.dart';

/// Builds a JSON string for the login API field `device_name`.
///
/// Lean snapshot: app version, locale/region, timezone, platform, and core
/// device / browser facts — no display metrics, accessibility, or raw dumps.
Future<String> buildLoginDeviceNameJson() async {
  final map = await collectLoginDeviceSnapshot();
  return jsonEncode(map);
}

/// Shorter JSON when `device_name` has a strict server `max:` length.
Map<String, dynamic> compactDeviceSnapshotMap(Map<String, dynamic> full) {
  final app = full['app'] as Map<String, dynamic>?;
  final loc = full['locale'] as Map<String, dynamic>?;
  final tz = full['tz'] as Map<String, dynamic>?;
  final client = full['client'] as Map<String, dynamic>?;
  final dev = full['device'] as Map<String, dynamic>?;
  String? ua;
  if (dev != null && dev['os'] == 'web') {
    final raw = dev['ua'] as String?;
    if (raw != null) {
      ua = raw.length <= 120 ? raw : '${raw.substring(0, 117)}...';
    }
  }
  final m = <String, dynamic>{
    'schema': 'login_client_compact_v1',
    'device_label': _shortDeviceLabel(full['device_label'] as String?, 72),
    'version': app?['version'],
    'build': app?['build'],
    'package': app?['package'],
    'locale_tag': loc?['tag'],
    'region': loc?['region'],
    'tz_offset_min': tz?['offset_min'],
    'platform': client?['platform'],
    'is_web': client?['is_web'],
    if (dev != null && dev['os'] == 'web')
      ...{
        'browser': dev['browser'],
        'user_agent': ?ua,
      },
  };
  m.removeWhere((_, v) => v == null);
  return m;
}

/// Tiny fallback if [compactDeviceSnapshotMap] still exceeds the API limit.
Map<String, dynamic> minimalDeviceSnapshotMap(Map<String, dynamic> full) {
  final app = full['app'] as Map<String, dynamic>?;
  final client = full['client'] as Map<String, dynamic>?;
  final m = <String, dynamic>{
    'schema': 'login_client_minimal_v1',
    'device_label': _shortDeviceLabel(full['device_label'] as String?, 40),
    'version': app?['version'],
    'build': app?['build'],
    'platform': client?['platform'],
    'is_web': client?['is_web'],
  };
  m.removeWhere((_, v) => v == null);
  return m;
}

String _shortDeviceLabel(String? label, int maxChars) {
  if (label == null || label.isEmpty) return 'unknown';
  if (label.length <= maxChars) return label;
  if (maxChars <= 1) return '…';
  return '${label.substring(0, maxChars - 1)}…';
}

String? _shortUa(String? ua, int max) {
  if (ua == null || ua.isEmpty) return null;
  if (ua.length <= max) return ua;
  return '${ua.substring(0, max - 3)}...';
}

Future<Map<String, dynamic>> collectLoginDeviceSnapshot() async {
  final pkg = await PackageInfo.fromPlatform();
  final now = DateTime.now();
  final locale = ui.PlatformDispatcher.instance.locale;
  final info = await DeviceInfoPlugin().deviceInfo;

  return {
    'schema': 'login_client_snapshot_v3',
    'at_utc': now.toUtc().toIso8601String(),
    'tz': {
      'name': now.timeZoneName,
      'offset_min': now.timeZoneOffset.inMinutes,
    },
    'locale': {
      'tag': locale.toLanguageTag(),
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        'region': locale.countryCode,
    },
    'app': {
      'version': pkg.version,
      'build': pkg.buildNumber,
      'package': pkg.packageName,
    },
    'client': {
      'platform': defaultTargetPlatform.name,
      'is_web': kIsWeb,
      'release': kReleaseMode,
    },
    'device': _deviceEssentials(info),
    'device_label': _deviceLabel(info),
  };
}

Map<String, dynamic> _deviceEssentials(BaseDeviceInfo info) {
  if (info is AndroidDeviceInfo) {
    return {
      'os': 'android',
      'manufacturer': info.manufacturer,
      'model': info.model,
      'brand': info.brand,
      'android_release': info.version.release,
      'sdk': info.version.sdkInt,
      'emu': !info.isPhysicalDevice,
    }..removeWhere((_, v) => v == null);
  }
  if (info is IosDeviceInfo) {
    return {
      'os': 'ios',
      'model': info.modelName.isNotEmpty ? info.modelName : info.model,
      'system': info.systemVersion,
      'emu': !info.isPhysicalDevice,
    }..removeWhere((_, v) => v == null);
  }
  if (info is WebBrowserInfo) {
    return {
      'os': 'web',
      'browser': info.browserName.name,
      'navigator_platform': info.platform,
      'ua': _shortUa(info.userAgent, 200),
    }..removeWhere((_, v) => v == null);
  }
  if (info is MacOsDeviceInfo) {
    return {
      'os': 'macos',
      'model': info.model,
      'os_release': info.osRelease,
    }..removeWhere((_, v) => v == null);
  }
  if (info is WindowsDeviceInfo) {
    return {
      'os': 'windows',
      'product': info.productName,
      'display_version': info.displayVersion,
    }..removeWhere((_, v) => v == null);
  }
  if (info is LinuxDeviceInfo) {
    return {
      'os': 'linux',
      'name': info.prettyName,
      'version_id': info.versionId,
    }..removeWhere((_, v) => v == null);
  }
  return {'os': 'unknown'};
}

String _deviceLabel(BaseDeviceInfo info) {
  if (info is AndroidDeviceInfo) {
    final parts = <String>[
      info.manufacturer,
      info.model,
      if (info.product.isNotEmpty) '(${info.product})',
    ];
    return parts.join(' ').trim();
  }
  if (info is IosDeviceInfo) {
    final parts = <String>[
      if (info.modelName.isNotEmpty) info.modelName,
      info.name,
      'hw:${info.utsname.machine}',
    ];
    return parts.join(' · ').trim();
  }
  if (info is WebBrowserInfo) {
    final plat = info.platform ?? 'web';
    return '${info.browserName.name} · $plat';
  }
  if (info is MacOsDeviceInfo) {
    return '${info.model} · ${info.osRelease}';
  }
  if (info is WindowsDeviceInfo) {
    return '${info.computerName} · ${info.displayVersion}';
  }
  if (info is LinuxDeviceInfo) {
    return '${info.prettyName} · ${info.version ?? info.name}';
  }
  return 'unknown';
}
