import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web Push certificate (public VAPID key) from Firebase Console:
/// Project settings → Cloud Messaging → Web Push certificates.
///
/// Override at build time: `--dart-define=FCM_WEB_VAPID_KEY=...`
const String kFcmWebVapidKey = String.fromEnvironment(
  'FCM_WEB_VAPID_KEY',
  defaultValue:
      'BFG4aiBB8_NC4TEFZzm_d9_zC1XNLqw6mJaEiVpYAC93yCzR3sQ1-g0IkjgEEDIiV8QLxj1DOXAiGhp8kAUMkS0',
);

/// FCM device token for the login/API payload.
///
/// On **web**, [FirebaseMessaging.getToken] requires [vapidKey]; without it
/// the plugin returns null or fails silently when caught upstream.
Future<String?> getFcmTokenForApi({
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    if (kIsWeb) {
      if (kFcmWebVapidKey.isEmpty) return null;
      return await FirebaseMessaging.instance
          .getToken(vapidKey: kFcmWebVapidKey)
          .timeout(timeout, onTimeout: () => null);
    }
    return await FirebaseMessaging.instance
        .getToken()
        .timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  }
}
