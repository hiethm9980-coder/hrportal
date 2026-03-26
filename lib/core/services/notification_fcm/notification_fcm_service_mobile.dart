// notification_fcm_service_mobile.dart

import 'dart:convert';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:hr_portal/core/services/awesome_notification_service.dart';
import 'package:hr_portal/core/services/db/db_helper.dart';
import 'package:hr_portal/core/services/notification_fcm/topic_service.dart';
import 'package:hr_portal/core/services/notifications_bus.dart';

class NotificationFCMService {
  static const String _defaultTopic = 'hr_portal';
  static const String _tableNotifications = 'notifications';

  RemoteMessage? _initialMessage;
  bool _inited = false;

  Future<void> initFCM() async {
    if (_inited) return;
    _inited = true;

    try {
      // 1) Permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS: بما أنك تعرض إشعار محلي عبر Awesome، خلها false لتجنب التكرار
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );

      // 2) Token (with timeout to prevent hanging)
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      log('fcmToken: $token');

      // 3) Subscribe to topic — fire-and-forget (لا ننتظره لتجنب التعليق)
      TopicService.subscribe(_defaultTopic);

      // 4) Token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        log('fcmToken refreshed: $t');
        await TopicService.subscribe(_defaultTopic);
      });

      // 5) Terminated
      _initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      // 6) Foreground
      FirebaseMessaging.onMessage.listen((m) async {
        await _onForegroundMessage(m);
      });

      // 7) Opened from system notification (لو حصل)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenSafely);
    } catch (e, s) {
      log('initFCM error: $e', stackTrace: s);
    }
  }

  /// استدعها بعد runApp (PostFrame) باستخدام نفس الـ instance الذي نفذ initFCM()
  Future<void> handleInitialMessageAfterAppReady() async {
    final msg = _initialMessage;
    if (msg == null) return;
    _initialMessage = null;
    await _handleOpen(msg);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final d = message.data;

    // ID لمنع التكرار
    final id =
        (d['id'] ??
                message.messageId ??
                DateTime.now().millisecondsSinceEpoch.toString())
            .toString();

    final titleEn = (d['title_en'] ?? d['title'] ?? 'Notification').toString();
    final bodyEn = (d['body_en'] ?? d['body'] ?? '').toString();
    final titleAr = (d['title_ar'] ?? titleEn).toString();
    final bodyAr = (d['body_ar'] ?? bodyEn).toString();

    if (titleEn.isEmpty && bodyEn.isEmpty) return;

    // 1) حفظ في SQLite
    final inserted = await _saveToLocalDb(
      id: id,
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      img: d['image']?.toString(),
      url: d['url']?.toString(),
      route: d['route']?.toString(),
      payload: d,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // ✅ لا تعرض إشعار مكرر (نفس ID)
    if (!inserted) return;

    // 2) عرض إشعار محلي عبر Awesome
    await AwesomeNotificationService.showLocalizedNotification(
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      imageUrl: d['image']?.toString(),
      payload: d.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// يحفظ الإشعار محليًا ويُرجّع true إذا تم الإدخال فعلاً.
  /// إذا كان مكرر (نفس id) سيرجع false.
  Future<bool> _saveToLocalDb({
    required String id,
    required String titleAr,
    required String bodyAr,
    required String titleEn,
    required String bodyEn,
    String? img,
    String? url,
    String? route,
    Map<String, dynamic>? payload,
    required int createdAt,
  }) async {
    try {
      final obj = <String, Object?>{
        'id': id,
        'title_ar': titleAr,
        'body_ar': bodyAr,
        'title_en': titleEn,
        'body_en': bodyEn,
        'img': img,
        'url': url,
        'route': route,
        'payload': payload == null ? null : jsonEncode(payload),
        'is_read': 0,
        'created_at': createdAt,
      }..removeWhere((k, v) => v == null);

      final inserted = await DbHelper().insertOrIgnore(
        table: _tableNotifications,
        obj: obj,
      );

      if (inserted == 1) {
        NotificationsBus.notifyChanged();
        return true;
      }
    } catch (e, s) {
      log('save notification failed: $e', stackTrace: s);
    }

    return false;
  }

  void _handleOpenSafely(RemoteMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _handleOpen(message);
    });
  }

  Future<void> _handleOpen(RemoteMessage message) async {
    final d = message.data;

    final id = d['id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        await DbHelper().update(
          table: _tableNotifications,
          obj: {'is_read': 1},
          condition: 'id = ?',
          conditionParams: [id],
        );
        // ✅ حدّث الواجهة/العداد فورًا
        NotificationsBus.notifyChanged();
      } catch (_) {}
    }

    final route = d['route']?.toString();
    if (route != null && route.isNotEmpty) {
      // لاحقًا: تنقل بالـ GoRouter إذا رغبت
    } else {
      log('FCM open without route: data=$d');
    }
  }
}
