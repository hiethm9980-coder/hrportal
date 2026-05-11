import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TopicService {
  /// Subscribes with retries. The first attempt right after a fresh Play Store
  /// install can race with the FCM token registration, leaving the device
  /// unsubscribed silently. We retry a few times with backoff until either
  /// it succeeds or we give up.
  static Future<void> subscribe(String topic) async {
    if (kIsWeb) {
      log('subscribeToTopic not supported on Web');
      return;
    }

    const maxAttempts = 5;
    var delay = const Duration(seconds: 2);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Make sure a token exists first — topic registration depends on it.
        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (token == null || token.isEmpty) {
          throw StateError('FCM token not ready yet');
        }

        await FirebaseMessaging.instance
            .subscribeToTopic(topic)
            .timeout(const Duration(seconds: 15));
        log('✅ Subscribed to $topic (attempt $attempt)');
        return;
      } catch (e, s) {
        log(
          '❌ Subscribe attempt $attempt/$maxAttempts to $topic failed: $e',
          stackTrace: s,
        );
        if (attempt == maxAttempts) return;
        await Future.delayed(delay);
        delay *= 2; // 2s, 4s, 8s, 16s
      }
    }
  }

  static Future<void> unsubscribe(String topic) async {
    if (kIsWeb) return;

    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      log('✅ Unsubscribed from $topic');
    } catch (e, s) {
      log('❌ Unsubscribe failed: $e', stackTrace: s);
    }
  }
}
