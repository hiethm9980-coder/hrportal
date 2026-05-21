import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_portal/core/services/awesome_notification_service.dart';
import 'package:hr_portal/core/services/db/db_helper.dart';
import 'package:hr_portal/core/services/notification_fcm/fcm_token_helper.dart';
import 'package:hr_portal/core/services/notifications_bus.dart';
import 'package:hr_portal/router/app_router.dart';

class NotificationFCMService {
  static const String _tableNotifications = 'notifications';

  RemoteMessage? _initialMessage;
  bool _inited = false;

  /// Web FCM initialization — **does NOT request notification permission**.
  ///
  /// Permission must be triggered by an explicit user gesture (login button
  /// or notification bell icon) via [requestWebPermissionAndToken]. Browsers
  /// (especially on mobile) often suppress the permission prompt entirely
  /// when fired on page-load — by deferring to a click handler we get a
  /// reliable user-gesture context. If permission was previously granted,
  /// the token is fetched silently here so push delivery works immediately.
  Future<void> initFCM() async {
    debugPrint('initFCM(web)');
    if (_inited) return;
    _inited = true;

    try {
      // 1) Listeners (cheap; safe to register before permission).
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        debugPrint('web fcmToken refreshed: $token');
      });

      _initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      FirebaseMessaging.onMessage.listen((message) async {
        await _onForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenSafely);

      // 2) If the user previously granted permission for this origin, fetch
      // the token silently (no prompt). For a fresh origin (status =
      // notDetermined), we wait for an explicit user action.
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized &&
          kFcmWebVapidKey.isNotEmpty) {
        final token =
            await FirebaseMessaging.instance.getToken(vapidKey: kFcmWebVapidKey);
        debugPrint('web fcmToken (existing grant): $token');
      } else {
        log(
          'web notifications: permission=${settings.authorizationStatus} — '
          'waiting for user gesture (login / bell icon) to request.',
        );
      }
    } catch (e, s) {
      log('initFCM(web) error: $e', stackTrace: s);
    }
  }

  /// Request the browser notification permission **only if it hasn't been
  /// decided yet**. Should be called from an explicit user gesture (button
  /// click, icon tap). Safe to call multiple times — it short-circuits when
  /// the user already granted or blocked permission.
  ///
  /// Returns `true` when permission ends up `authorized`, `false` otherwise.
  /// The browser remembers the decision; we won't keep re-prompting.
  Future<bool> requestWebPermissionAndToken() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final status = settings.authorizationStatus;

      // Already decided (Allow OR Block) → never re-prompt. If allowed,
      // ensure we have a current token.
      if (status == AuthorizationStatus.authorized) {
        if (kFcmWebVapidKey.isNotEmpty) {
          final token = await FirebaseMessaging.instance
              .getToken(vapidKey: kFcmWebVapidKey);
          debugPrint('web fcmToken (re-check): $token');
        }
        return true;
      }
      if (status == AuthorizationStatus.denied) {
        log('web notifications already blocked by user — not re-prompting.');
        return false;
      }

      // Status is notDetermined / provisional — safe to request now.
      final result = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      log('web notification permission result: ${result.authorizationStatus}');

      final granted =
          result.authorizationStatus == AuthorizationStatus.authorized;
      if (granted && kFcmWebVapidKey.isNotEmpty) {
        final token = await FirebaseMessaging.instance
            .getToken(vapidKey: kFcmWebVapidKey);
        debugPrint('web fcmToken (after grant): $token');
      } else if (kFcmWebVapidKey.isEmpty) {
        log(
          'FCM_WEB_VAPID_KEY is missing. Run with '
          '--dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY',
        );
      }
      return granted;
    } catch (e, s) {
      log('requestWebPermissionAndToken error: $e', stackTrace: s);
      return false;
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
      voice: d['voice']?.toString(),
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

