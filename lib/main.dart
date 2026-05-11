import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hr_portal/core/services/awesome_notification_service.dart';
import 'package:hr_portal/core/services/db/db_helper.dart';
import 'package:hr_portal/core/services/notification_fcm/notification_fcm_service.dart';
import 'package:hr_portal/firebase_options.dart';
import 'package:pwa_install/pwa_install.dart';

import 'core/config/app_config.dart';
import 'core/config/app_logger.dart';
import 'core/config/crash_reporter.dart';
import 'core/constants/api_constants.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/storage/secure_token_storage.dart';
import 'injection.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // يضمن تسجيل البلجنز في هذا الـ isolate (لتفادي MissingPluginException)
  DartPluginRegistrant.ensureInitialized();

  // ✅ سجلات تظهر في `adb logcat` حتى في الـ release. للفلترة:
  //   adb logcat | findstr /i "flutter Awesome FCM 🔥"
  debugPrint(
    '🔥 [BG] FCM message received id=${message.messageId} data=${message.data}',
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🔥 [BG] Firebase.initializeApp failed: $e');
  }

  try {
    await AwesomeNotificationService.initForBackground();
  } catch (e) {
    debugPrint('🔥 [BG] AwesomeNotifications initForBackground failed: $e');
  }

  final d = message.data;

  // ✅ ID فريد للإشعار. نستخدمه أيضاً كـ deduplication key لـ Awesome
  // (نفس ID لا يُعرض مرتين). إذا السيرفر يرسل data['id'] استخدمه.
  final id = (d['id'] ??
          message.messageId ??
          DateTime.now().millisecondsSinceEpoch.toString())
      .toString();

  final titleEn = (d['title_en'] ?? d['title'] ?? 'Notification').toString();
  final bodyEn = (d['body_en'] ?? d['body'] ?? '').toString();
  final titleAr = (d['title_ar'] ?? titleEn).toString();
  final bodyAr = (d['body_ar'] ?? bodyEn).toString();

  // إذا ما فيه محتوى لا نعرض ولا نحفظ
  if (titleEn.isEmpty && bodyEn.isEmpty) {
    debugPrint('🔥 [BG] Empty title/body, skipping');
    return;
  }

  final createdAt = int.tryParse((d['created_at'] ?? '').toString()) ??
      DateTime.now().millisecondsSinceEpoch;

  // ✅ 1) اعرض الإشعار أولاً — لا تجعل عرض الإشعار يعتمد على نجاح حفظ DB.
  // في background isolate قد يفشل فتح SQLite (lock من main isolate في
  // غياب WAL، schema mismatch، أو أي سبب آخر) فلا يجوز أن يمنع ذلك ظهور
  // الإشعار للمستخدم. الـ deduplication يضمنه Awesome نفسه عبر notificationId
  // الفريد المشتق من id (انظر showLocalizedNotification).
  try {
    await AwesomeNotificationService.showLocalizedNotification(
      notificationId: id,
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      imageUrl: d['image']?.toString(),
      voice: d['voice']?.toString(),
      payload: d.map((k, v) => MapEntry(k, v.toString())),
    );
    debugPrint('🔥 [BG] Awesome notification shown id=$id');
  } catch (e, s) {
    debugPrint('🔥 [BG] Awesome show failed: $e\n$s');
  }

  // ✅ 2) ثم احفظ في DB (في try مستقل) — فشل الحفظ لا يلغي عرض الإشعار.
  try {
    final inserted = await DbHelper().insertOrIgnore(
      table: 'notifications',
      obj: {
        'id': id,
        'title_ar': titleAr,
        'body_ar': bodyAr,
        'title_en': titleEn,
        'body_en': bodyEn,
        'img': d['image']?.toString(),
        'url': d['url']?.toString(),
        'route': d['route']?.toString(),
        'payload': jsonEncode(d),
        'is_read': 0,
        'created_at': createdAt,
      }..removeWhere((k, v) => v == null),
    );
    debugPrint('🔥 [BG] DB insert result=$inserted id=$id');
  } catch (e, s) {
    debugPrint('🔥 [BG] DB insert failed: $e\n$s');
  }
}

/// Detects if the API base URL changed since last run.
/// If changed, clears all session data so the user is forced to re-login.
/// Returns true if the URL changed (session was cleared).
Future<bool> clearIfBaseUrlChanged(String currentUrl) async {
  final storage = sl<SecureTokenStorage>();
  final lastUrl = await storage.getLastBaseUrl();

  if (lastUrl != null && lastUrl != currentUrl) {
    AppLogger.i(
      'Base URL changed: $lastUrl → $currentUrl. Clearing session.',
      tag: 'Boot',
    );
    await storage.clearAll();
    await storage.saveBaseUrl(currentUrl);
    return true;
  }

  // Always save the current URL for next comparison.
  await storage.saveBaseUrl(currentUrl);
  return false;
}

/// Global app config — accessible anywhere after init.
late final AppConfig appConfig;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every in-app header uses `AppColors.navyGradient` at the very top, so
  // the status bar (clock / signal / wifi / battery) always sits on a
  // dark surface. Force the system icons to render white + keep the bar
  // transparent so the gradient shows through. AppBarTheme already does
  // this for screens that use AppBar — this covers everything else.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark,       // iOS
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await AwesomeNotificationService.init();
  final fcmService = NotificationFCMService();
  debugPrint('main: before initFCM');
  try {
    await fcmService.initFCM().timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('main: initFCM timed out or failed: $e');
  }
  debugPrint('main: after initFCM');

  // ── 1. Initialize AppConfig (base_url: dev = fixed; prod = Remote Config) ──
  appConfig = AppConfig(enableDebugLogs: true);
  AppConfig.logPlayStoreBuildHintIfNeeded();

  // ── 2. Initialize logging ──
  AppLogger.init(appConfig);
  AppLogger.i('Starting HR Mobile', tag: 'Boot');

  // ── 3. Configure API base URL from flavor ──
  ApiConstants.configure(appConfig);

  // ── 4. Initialize crash reporting ──
  await CrashReporter.init(appConfig);

  // ── 5. Initialize data-layer DI (GetIt) — NOT MODIFIED ──
  await initDependencies();

  // ── 5b. base URL change detection moved to splash_screen.dart ──

  AppLogger.i('All dependencies initialized', tag: 'Boot');

  // ── 6. Resolve initial language mode (saved → system) ──
  final initialLocaleMode = await loadStartupLocaleMode();

  // ── 6b. Resolve initial theme mode (saved → system) ──
  final initialThemeMode = await loadStartupThemeMode();

  if (kIsWeb) {
    PWAInstall().setup(
      installCallback: () {
        debugPrint('APP INSTALLED!');
      },
    );
  }

  // ── 7. Launch app ──
  runApp(
    ProviderScope(
      overrides: [
        initialLocaleModeProvider.overrideWithValue(initialLocaleMode),
        initialThemeModeProvider.overrideWithValue(initialThemeMode),
      ],
      child: const HrMobileApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // ✅ الآن التطبيق جاهز للتنقل
    fcmService.handleInitialMessageAfterAppReady();

    if (!kIsWeb) {
      AwesomeNotificationService.handleInitialActionIfAny();
    }
  });
}
