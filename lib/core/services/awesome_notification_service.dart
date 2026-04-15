// awesome_notification_service.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_portal/core/services/notification_action_service.dart';
import 'package:hr_portal/router/app_router.dart';
import 'package:share_plus/share_plus.dart';

class AwesomeNotificationService {
  static const String channelKey = 'alerts_channel';
  static const String channelGroupKey = 'alerts_group';

  static bool _inited = false;
  static bool _bgInited = false;

  /// تهيئة الحزمة والقناة + تسجيل المستمعات
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await AwesomeNotifications().initialize(
      kIsWeb ? null : 'resource://drawable/ic_notify',
      [
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: channelKey,
          channelName: 'Alerts',
          channelDescription: 'Channel for app alerts',
          importance: NotificationImportance.High,
          channelShowBadge: true,
          defaultColor: const Color(0xffe7b245),
          ledColor: Colors.white,
          playSound: !kIsWeb,
          icon: kIsWeb ? null : 'resource://drawable/ic_notify',
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Alerts Group',
        ),
      ],
      debug: true,
    );

    AwesomeNotifications().setListeners(
      onNotificationCreatedMethod:
          AwesomeNotificationController.onNotificationCreatedMethod,
      onNotificationDisplayedMethod:
          AwesomeNotificationController.onNotificationDisplayedMethod,
      onActionReceivedMethod:
          AwesomeNotificationController.onActionReceivedMethod,
      onDismissActionReceivedMethod:
          AwesomeNotificationController.onDismissedActionReceivedMethod,
    );

    if (!kIsWeb) {
      await requestPermissionFromUser();
    }
  }

  static Future<void> initForBackground() async {
    if (_bgInited) return;
    _bgInited = true;
    await AwesomeNotifications().initialize(
      kIsWeb ? null : 'resource://drawable/ic_notify',
      [
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: channelKey,
          channelName: 'Alerts',
          channelDescription: 'Channel for app alerts',
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: !kIsWeb,
          icon: kIsWeb ? null : 'resource://drawable/ic_notify',
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Alerts Group',
        ),
      ],
      debug: false,
    );
  }

  static Future<void> requestPermissionFromUser() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> showLocalizedNotification({
    required String titleAr,
    required String bodyAr,
    required String titleEn,
    required String bodyEn,
    String? imageUrl,
    Map<String, String>? payload,
  }) async {
    if (kIsWeb) {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) return;
    }

    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final mergedPayload = <String, String>{
      if (payload != null) ...payload,
      'title': payload?['title'] ?? titleEn,
      'body': payload?['body'] ?? bodyEn,
    };

    // Determine if this is an approval notification (for managers).
    final route = payload?['route'];
    final isApproval = NotificationActionService.isApprovalRoute(route);

    // Build action buttons based on notification type.
    final List<NotificationActionButton> actionButtons;

    if (isApproval) {
      // Manager approval notification — show approve/reject with reply input.
      actionButtons = [
        NotificationActionButton(
          key: 'APPROVE',
          label: 'Approve',
          requireInputText: true,
          actionType: ActionType.SilentBackgroundAction,
          color: const Color(0xFF16A34A),
        ),
        NotificationActionButton(
          key: 'REJECT',
          label: 'Reject',
          requireInputText: true,
          actionType: ActionType.SilentBackgroundAction,
          color: const Color(0xFFDC2626),
        ),
      ];
    } else {
      // Employee notification — no action buttons.
      actionButtons = [];
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: titleEn,
        body: bodyEn,
        icon: kIsWeb ? null : 'resource://drawable/ic_notify',
        notificationLayout: hasImage
            ? NotificationLayout.BigPicture
            : NotificationLayout.BigText,
        bigPicture: hasImage ? imageUrl : null,
        largeIcon: hasImage ? imageUrl : null,
        hideLargeIconOnExpand: true,
        payload: mergedPayload,
      ),
      localizations: {
        'ar': NotificationLocalization(
          title: titleAr,
          body: bodyAr,
          buttonLabels: isApproval
              ? {'APPROVE': 'موافقة ✅', 'REJECT': 'رفض ❌'}
              : {},
        ),
        'en': NotificationLocalization(
          title: titleEn,
          body: bodyEn,
          buttonLabels: isApproval
              ? {'APPROVE': 'Approve ✅', 'REJECT': 'Reject ❌'}
              : {},
        ),
      },
      actionButtons: actionButtons,
    );
  }

  static Future<void> handleInitialActionIfAny() async {
    final initial = await AwesomeNotifications().getInitialNotificationAction(
      removeFromActionEvents: true,
    );
    if (initial != null) {
      await AwesomeNotificationController.onActionReceivedMethod(initial);
    }
  }
}

@pragma('vm:entry-point')
class AwesomeNotificationController {
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification received,
  ) async {
    debugPrint('🛠 [CREATED] id=${received.id} title=${received.title}');
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification received,
  ) async {
    debugPrint('👀 [DISPLAYED] id=${received.id} body=${received.body}');
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction action) async {
    // Ensure Flutter binding is available (needed in background isolate).
    WidgetsFlutterBinding.ensureInitialized();

    final String key = action.buttonKeyPressed;
    final bool isBodyTap = key.isEmpty || key == 'DEFAULT';

    debugPrint(
      '🖱️ [ACTION] key=${key.isEmpty ? '(body)' : key} type=${action.actionType}',
    );

    // ── Approve / Reject from notification ──
    if (key == 'APPROVE' || key == 'REJECT') {
      try {
        final route = action.payload?['route'];
        if (route == null || route.isEmpty) {
          debugPrint('📋 [DECISION] No route in payload, skipping');
          return;
        }

        final notes = action.buttonKeyInput;
        final decision = key == 'APPROVE' ? 'approved' : 'rejected';

        debugPrint('📋 [DECISION] $decision for route=$route notes="$notes"');

        // احذف الإشعار فوراً بعد الإرسال (لا ننتظر رد السيرفر).
        await AwesomeNotifications().dismiss(action.id!);

        final result = await NotificationActionService.executeDecision(
          route: route,
          decision: decision,
          notes: notes,
        );

        debugPrint('📋 [DECISION RESULT] success=${result.success} msg=${result.message}');

        if (!result.success) {
          // ❌ فشل — إشعار خطأ.
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: AwesomeNotificationService.channelKey,
              title: 'فشل الإجراء ⚠️ قم باتخاذ القرار من التطبيق',
              body: result.message ?? 'حدث خطأ غير متوقع',
              notificationLayout: NotificationLayout.Default,
            ),
          );
        }
      } catch (e, s) {
        debugPrint('📋 [DECISION ERROR] $e');
        debugPrint('📋 [DECISION STACK] $s');
        // Show error notification.
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: AwesomeNotificationService.channelKey,
            title: 'فشل الإجراء ⚠️ قم باتخاذ القرار من التطبيق',
            body: '$e',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      }
      return;
    }

    // ── Share ──
    if (key == 'SHARE') {
      final title = (action.title ?? '').trim();
      final body = (action.body ?? '').trim();

      String shareText;
      if (title.isNotEmpty && body.isNotEmpty) {
        shareText = '$title\n\n$body';
      } else if (title.isNotEmpty) {
        shareText = title;
      } else if (body.isNotEmpty) {
        shareText = body;
      } else {
        final pTitle = (action.payload?['title'] ?? '').trim();
        final pBody = (action.payload?['body'] ?? '').trim();
        shareText = [pTitle, pBody].where((s) => s.isNotEmpty).join('\n\n');
        if (shareText.isEmpty) shareText = 'No content to share';
      }

      final subject = title.isNotEmpty ? title : 'Share';
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: subject),
      );
      return;
    }

    // ── Body tap or OPEN ──
    if (isBodyTap || key == 'OPEN') {
      final route = action.payload?['route'];
      if (route != null && route.isNotEmpty) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ctx.go(route);
        } else {
          pendingDeepLink = route;
        }
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> onDismissedActionReceivedMethod(
    ReceivedAction action,
  ) async {
    debugPrint('❌ [DISMISSED] id=${action.id}');
    await AwesomeNotifications().setGlobalBadgeCounter(0);
  }
}
