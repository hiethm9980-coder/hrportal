// awesome_notification_service.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_portal/core/services/notification_action_service.dart';
import 'package:hr_portal/router/app_router.dart';
import 'package:share_plus/share_plus.dart';

class AwesomeNotificationService {
  /// القناة الافتراضية — تستخدم صوت النظام الافتراضي عندما لا يحدد السيرفر
  /// `voice` (أو يرسلها فارغة/null).
  static const String channelKey = 'alerts_channel';
  static const String channelGroupKey = 'alerts_group';

  /// خريطة `voice` → channelKey. كل قناة مرتبطة بملف صوت في
  /// `android/app/src/main/res/raw/<key>.ogg`.
  ///
  /// ملاحظة Android مهمة: بعد إنشاء قناة على الجهاز لا يمكن تغيير صوتها
  /// عبر الكود (قيد نظام Android 8+). لذلك نستخدم channelKey مختلف لكل
  /// صوت بدلاً من تعديل القناة الواحدة.
  static const Map<String, String> _voiceChannels = {
    'a': 'alerts_channel_a',
    'b': 'alerts_channel_b',
    'c': 'alerts_channel_c',
    'd': 'alerts_channel_d',
  };

  static bool _inited = false;
  static bool _bgInited = false;

  /// يبني قائمة القنوات (الافتراضية + قناة لكل صوت). تُستخدم في كلا
  /// الـ isolates (foreground و background) لضمان وجود نفس القنوات.
  static List<NotificationChannel> _buildChannels({required bool decorate}) {
    NotificationChannel build({
      required String key,
      required String name,
      String? soundSource,
    }) {
      return NotificationChannel(
        channelGroupKey: channelGroupKey,
        channelKey: key,
        channelName: name,
        channelDescription: 'Channel for app alerts',
        importance: NotificationImportance.High,
        channelShowBadge: true,
        defaultColor: decorate ? const Color(0xffe7b245) : null,
        ledColor: decorate ? Colors.white : null,
        playSound: !kIsWeb,
        soundSource: soundSource,
        icon: kIsWeb ? null : 'resource://drawable/ic_notify',
      );
    }

    return [
      build(key: channelKey, name: 'Alerts'),
      for (final entry in _voiceChannels.entries)
        build(
          key: entry.value,
          name: 'Alerts ${entry.key.toUpperCase()}',
          // ملف الصوت داخل res/raw/<key>.ogg — بدون اللاحقة.
          soundSource: 'resource://raw/${entry.key}',
        ),
    ];
  }

  /// يختار channelKey المناسب حسب `voice` القادم من السيرفر.
  /// - `null` / فارغ / قيمة غير معروفة → القناة الافتراضية (صوت النظام).
  /// - `"a"` / `"b"` / `"c"` / `"d"` → قناة الصوت المخصص المقابل.
  static String _channelKeyForVoice(String? voice) {
    final normalized = voice?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return channelKey;
    return _voiceChannels[normalized] ?? channelKey;
  }

  /// يفرض إعادة إنشاء قنوات الصوت بصوتها الصحيح. ضروري لأن Android 8+
  /// يُجمّد إعدادات الصوت لأي قناة فور إنشائها — ولا تتغير حتى لو غيّرناها
  /// في الكود. باستخدام `forceUpdate: true` تُحذف القناة وتُعاد بالصوت
  /// المحدّث (القناة الافتراضية لا تُلمس لتفادي إلغاء تخصيصات المستخدم).
  static Future<void> _forceUpdateVoiceChannels({required bool decorate}) async {
    for (final entry in _voiceChannels.entries) {
      try {
        await AwesomeNotifications().setChannel(
          NotificationChannel(
            channelGroupKey: channelGroupKey,
            channelKey: entry.value,
            channelName: 'Alerts ${entry.key.toUpperCase()}',
            channelDescription: 'Channel for app alerts',
            importance: NotificationImportance.High,
            channelShowBadge: true,
            defaultColor: decorate ? const Color(0xffe7b245) : null,
            ledColor: decorate ? Colors.white : null,
            playSound: !kIsWeb,
            soundSource: 'resource://raw/${entry.key}',
            icon: kIsWeb ? null : 'resource://drawable/ic_notify',
          ),
          forceUpdate: true,
        );
      } catch (e) {
        debugPrint('⚠️ setChannel ${entry.value} failed: $e');
      }
    }
  }

  /// تهيئة الحزمة والقناة + تسجيل المستمعات
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await AwesomeNotifications().initialize(
      kIsWeb ? null : 'resource://drawable/ic_notify',
      _buildChannels(decorate: true),
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Alerts Group',
        ),
      ],
      debug: true,
    );

    if (!kIsWeb) {
      await _forceUpdateVoiceChannels(decorate: true);
    }

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
      _buildChannels(decorate: false),
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Alerts Group',
        ),
      ],
      debug: false,
    );

    if (!kIsWeb) {
      await _forceUpdateVoiceChannels(decorate: false);
    }

    // Listeners are also needed in the background isolate so that events
    // created while the app is terminated are queued and delivered properly
    // once the main isolate resumes.
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
    String? notificationId,
    String? voice,
  }) async {
    if (kIsWeb) {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) return;
    }

    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    // ✅ إذا أُرسل notificationId ثابت (ID الإشعار من السيرفر) نشتق منه int
    // مستقر لـ Awesome، حتى لا يُعرض نفس الإشعار مرتين لو وصل من FCM في
    // حالتين مختلفتين (foreground + background) أو أُعيد إرساله. بدون ذلك
    // نستخدم timestamp عشوائياً.
    final int id = notificationId != null && notificationId.isNotEmpty
        ? (notificationId.hashCode & 0x7FFFFFFF) % 2147483647
        : DateTime.now().millisecondsSinceEpoch.remainder(100000);

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

    final selectedChannelKey = _channelKeyForVoice(voice);
    debugPrint(
      '🔔 [VOICE] raw="$voice" → channel="$selectedChannelKey"',
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: selectedChannelKey,
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
        category: NotificationCategory.Message,
        wakeUpScreen: true,
        displayOnForeground: true,
        displayOnBackground: true,
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
          // Awesome notifications are only shown while the app is live
          // (they're created inside the FCM `onMessage` foreground handler),
          // so a body tap is always a WARM path — push on top of the current
          // stack so Back returns to the previous screen instead of exiting.
          ctx.push(route);
        } else {
          // Edge case: app already torn down — let the router redirect
          // consume it as a cold deep-link (uses go, Back → home).
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
