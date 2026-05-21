// awesome_notification_service.dart
import 'dart:ui' as ui;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_portal/core/constants/storage_keys.dart';
import 'package:hr_portal/core/services/notification_action_service.dart';
import 'package:hr_portal/router/app_router.dart';
import 'package:share_plus/share_plus.dart';

class AwesomeNotificationService {
  /// القناة الافتراضية — تستخدم صوت النظام الافتراضي عندما لا يحدد السيرفر
  /// `voice` (أو يرسلها فارغة/null).
  static const String channelKey = 'alerts_channel';
  static const String channelGroupKey = 'alerts_group';

  /// لون خلفية أيقونة الإشعار (الدائرة الصغيرة خلف الـ silhouette الأبيض).
  /// يحل مشكلة "أيقونة بيضاء على خلفية بيضاء = غير مرئية" على بعض الأجهزة.
  static const Color notificationAccentColor = Color(0xFF0F2952);

  /// خريطة `voice` → channelKey. كل قناة مرتبطة بملف صوت في
  /// `android/app/src/main/res/raw/<key>.wav`.
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
        // اللون يطبَّق دائماً لضمان ظهور دائرة ملونة خلف الأيقونة على جميع
        // الأجهزة — وإلا تظهر بيضاء على بيضاء.
        defaultColor: notificationAccentColor,
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
          // ملف الصوت داخل res/raw/<key>.wav — يُمرَّر بدون اللاحقة.
          soundSource: 'resource://raw/${entry.key}',
        ),
    ];
  }

  /// تُعيد لغة الإشعار الفعلية ("ar" أو "en") بناءً على تفضيل التطبيق
  /// المحفوظ في `flutter_secure_storage`:
  /// - إذا كان المستخدم اختار "ar" → عربي
  /// - إذا كان المستخدم اختار "en" → إنجليزي
  /// - إذا كان "system" أو غير محدد → نتبع لغة الجهاز (ar / غير ذلك → en)
  ///
  /// تعمل في كلا الـ isolates (foreground و background) لأن
  /// `flutter_secure_storage` يعتمد على platform channels يُهيّئها
  /// `DartPluginRegistrant.ensureInitialized()` المُستدعى في
  /// `_firebaseMessagingBackgroundHandler`.
  static Future<String> _resolveAppLanguage() async {
    try {
      const storage = FlutterSecureStorage();
      final saved = (await storage.read(key: StorageKeys.locale))
          ?.trim()
          .toLowerCase();
      if (saved == 'ar') return 'ar';
      if (saved == 'en') return 'en';
      // 'system' أو null → اتبع لغة الجهاز.
      // ملاحظة: نستخدم `ui.PlatformDispatcher.instance` بدلاً من
      // `WidgetsBinding.instance.platformDispatcher` لأنها متاحة في أي
      // isolate (بما فيه background isolate في terminated state) بدون
      // الحاجة لتهيئة WidgetsFlutterBinding.
      final dispatcher = ui.PlatformDispatcher.instance;
      final locales = dispatcher.locales;
      final device = locales.isNotEmpty ? locales.first : dispatcher.locale;
      return device.languageCode.toLowerCase() == 'ar' ? 'ar' : 'en';
    } catch (_) {
      return 'en';
    }
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
            defaultColor: notificationAccentColor,
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

    // ✅ نقرأ لغة التطبيق المحفوظة (وليس لغة الجهاز) ثم نختار العنوان/النص
    // المناسبين مباشرة. هكذا يصل الإشعار للمستخدم بلغة تطبيقه حتى لو كانت
    // مختلفة عن لغة نظام الهاتف.
    final String lang = await _resolveAppLanguage();
    final bool isArabic = lang == 'ar';
    final String effectiveTitle = isArabic ? titleAr : titleEn;
    final String effectiveBody = isArabic ? bodyAr : bodyEn;

    final mergedPayload = <String, String>{
      if (payload != null) ...payload,
      'title': payload?['title'] ?? effectiveTitle,
      'body': payload?['body'] ?? effectiveBody,
    };

    // Determine if this is an approval notification (for managers).
    final route = payload?['route'];
    final isApproval = NotificationActionService.isApprovalRoute(route);

    // Build action buttons based on notification type — تسميات الأزرار
    // تتبع لغة التطبيق أيضاً.
    final List<NotificationActionButton> actionButtons;

    if (isApproval) {
      // Manager approval notification — show approve/reject with reply input.
      actionButtons = [
        NotificationActionButton(
          key: 'APPROVE',
          label: isArabic ? 'موافقة ✅' : 'Approve ✅',
          requireInputText: true,
          actionType: ActionType.SilentBackgroundAction,
          color: const Color(0xFF16A34A),
        ),
        NotificationActionButton(
          key: 'REJECT',
          label: isArabic ? 'رفض ❌' : 'Reject ❌',
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
      '🔔 [VOICE] raw="$voice" → channel="$selectedChannelKey" | lang="$lang"',
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: selectedChannelKey,
        title: effectiveTitle,
        body: effectiveBody,
        icon: kIsWeb ? null : 'resource://drawable/ic_notify',
        // ✅ يضمن ظهور خلفية ملوّنة (دائرة) خلف الـ silhouette الأبيض على
        // جميع الأجهزة. بدونها بعض ROMs (مثل Samsung/Xiaomi) تتجاهل لون
        // القناة وتعرض الأيقونة بيضاء على خلفية بيضاء — فلا تظهر إطلاقاً.
        color: notificationAccentColor,
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
      // ملاحظة: لا نمرر `localizations` بعد الآن، لأنها تعتمد على لغة
      // الجهاز. التحويل تم يدويًا أعلاه بحسب لغة التطبيق.
      actionButtons: actionButtons,
    );

    // ✅ زيادة عدّاد البادج على أيقونة التطبيق (Launcher Badge). يظهر على
    // أجهزة Android التي يدعم launcher-ها الـ badges (Samsung/Xiaomi/Oppo/
    // Pixel-with-launcher-support) وعلى iOS عبر APNs. يُصفَّر عند ضغط أيقونة
    // الجرس في الـ Dashboard أو فتح شاشة الإشعارات. لا نمنع عرض الإشعار لو
    // فشل تحديث البادج (نادر).
    try {
      await AwesomeNotifications().incrementGlobalBadgeCounter();
    } catch (e) {
      debugPrint('⚠️ incrementGlobalBadgeCounter failed: $e');
    }
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
            color: AwesomeNotificationService.notificationAccentColor,
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
    // لا نُصفّر البادج هنا — حذف إشعار واحد من شريط النظام لا يعني أن
    // المستخدم رأى كل الإشعارات. التصفير يحدث فقط عند ضغط أيقونة الجرس
    // في الـ Dashboard أو فتح شاشة الإشعارات.
  }
}
