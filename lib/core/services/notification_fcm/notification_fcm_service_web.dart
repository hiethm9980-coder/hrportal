import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_portal/core/services/awesome_notification_service.dart';
import 'package:hr_portal/core/services/db/db_helper.dart';
import 'package:hr_portal/core/services/notifications_bus.dart';
import 'package:hr_portal/router/app_router.dart';

class NotificationFCMService {
  static const String _tableNotifications = 'notifications';

  // مرره عند التشغيل:
  // flutter run -d chrome --dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY
  // static const String _webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
  static const String _webVapidKey = "BFG4aiBB8_NC4TEFZzm_d9_zC1XNLqw6mJaEiVpYAC93yCzR3sQ1-g0IkjgEEDIiV8QLxj1DOXAiGhp8kAUMkS0";

  RemoteMessage? _initialMessage;
  bool _inited = false;

  Future<void> initFCM() async {
    print('initFCM(web)');
    if (_inited) return;
    _inited = true;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      log('web notification permission: ${settings.authorizationStatus}');

      if (_webVapidKey.isEmpty) {
        log(
          'FCM_WEB_VAPID_KEY is missing. Run with '
          '--dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY',
        );
      } else {
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey: _webVapidKey,
        );
        print('web fcmToken: $token');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        print('web fcmToken refreshed: $token');
      });

      _initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      FirebaseMessaging.onMessage.listen((message) async {
        await _onForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenSafely);
    } catch (e, s) {
      log('initFCM(web) error: $e', stackTrace: s);
    }
  }

  Future<void> handleInitialMessageAfterAppReady() async {
    final msg = _initialMessage;
    if (msg == null) return;
    _initialMessage = null;
    await _handleOpen(msg);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final d = Map<String, dynamic>.from(message.data);
    final notification = message.notification;

    final id =
        (d['id'] ??
                message.messageId ??
                DateTime.now().millisecondsSinceEpoch.toString())
            .toString();

    final titleEn =
        (d['title_en'] ?? d['title'] ?? notification?.title ?? 'Notification')
            .toString();

    final bodyEn =
        (d['body_en'] ?? d['body'] ?? notification?.body ?? '').toString();

    final titleAr = (d['title_ar'] ?? titleEn).toString();
    final bodyAr = (d['body_ar'] ?? bodyEn).toString();

    final routeValue = d['route']?.toString();
    final route = (routeValue != null && routeValue.isNotEmpty)
        ? routeValue
        : (_routeFromUrl(d['url']?.toString()) ?? '');

    if (titleEn.isEmpty && bodyEn.isEmpty) return;

    final inserted = await _saveToLocalDb(
      id: id,
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      img: d['image']?.toString(),
      url: d['url']?.toString(),
      route: route,
      payload: d,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (!inserted) return;

    await AwesomeNotificationService.showLocalizedNotification(
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      imageUrl: d['image']?.toString(),
      payload: {
        ...d.map((k, v) => MapEntry(k, v.toString())),
        if (route.isNotEmpty) 'route': route,
      },
    );

    // Notify screens to auto-refresh if the route is relevant.
    if (route.isNotEmpty) {
      NotificationsBus.notifyRouteChanged(route);
    }
  }

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
        NotificationsBus.notifyChanged();
      } catch (_) {}
    }

    final route = d['route']?.toString() ?? _routeFromUrl(d['url']?.toString());
    if (route != null && route.isNotEmpty) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.go(route);
      } else {
        pendingDeepLink = route;
      }
    }
  }

  String? _routeFromUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;

    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;

    if (!uri.hasScheme) {
      return rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    }

    final sameOrigin = uri.host == Uri.base.host;
    if (!sameOrigin) return null;

    final path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery) {
      return '$path?${uri.query}';
    }
    return path;
  }
}

