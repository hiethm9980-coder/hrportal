import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تهيئة خفيفة للقنوات فقط
  await AwesomeNotificationService.initForBackground();

  final d = message.data;

  // ✅ ID لمنع التكرار (يفضل أن ترسله من السيرفر داخل data["id"])
  final id = (d['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

  // ✅ اعتمد على data-only
  final titleEn = (d['title_en'] ?? d['title'] ?? 'Notification').toString();
  final bodyEn = (d['body_en'] ?? d['body'] ?? '').toString();
  final titleAr = (d['title_ar'] ?? titleEn).toString();
  final bodyAr = (d['body_ar'] ?? bodyEn).toString();

  // إذا ما فيه محتوى لا تحفظ ولا تعرض
  if (titleEn.isEmpty && bodyEn.isEmpty) return;

  // ✅ created_at: إذا السيرفر يرسله كـ epoch استخدمه، وإلا استخدم الآن
  final createdAt = int.tryParse((d['created_at'] ?? '').toString()) ?? DateTime.now().millisecondsSinceEpoch;

  // ✅ 1) احفظ في SQLite (بدون تكرار)
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

  if (inserted == 0) return; // ✅ لا تعرض المكرر

  // ✅ 2) ثم اعرض الإشعار محليًا عبر Awesome
  await AwesomeNotificationService.showLocalizedNotification(
    titleAr: titleAr,
    bodyAr: bodyAr,
    titleEn: titleEn,
    bodyEn: bodyEn,
    imageUrl: d['image']?.toString(),
    payload: d.map((k, v) => MapEntry(k, v.toString())),
  );
}

/// Detects if the API base URL changed since last run.
/// If changed, clears all session data so the user is forced to re-login.
Future<void> _clearIfBaseUrlChanged(String currentUrl) async {
  final storage = sl<SecureTokenStorage>();
  final lastUrl = await storage.getLastBaseUrl();

  if (lastUrl != null && lastUrl != currentUrl) {
    AppLogger.i(
      'Base URL changed: $lastUrl → $currentUrl. Clearing session.',
      tag: 'Boot',
    );
    await storage.clearAll();
  }

  // Always save the current URL for next comparison.
  await storage.saveBaseUrl(currentUrl);
}

/// Global app config — accessible anywhere after init.
late final AppConfig appConfig;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await AwesomeNotificationService.init();
  final fcmService = NotificationFCMService();
  print('main: before initFCM');
  await fcmService.initFCM();
  print('main: after initFCM');

  // ── 1. Resolve environment from --dart-define=FLAVOR ──
  appConfig = AppConfig.fromEnvironment();

  // ── 2. Initialize flavor-aware logging ──
  AppLogger.init(appConfig);
  AppLogger.i('Starting HR Mobile (${appConfig.envName})', tag: 'Boot');

  // ── 3. Configure API base URL from flavor ──
  ApiConstants.configure(appConfig);

  // ── 4. Initialize crash reporting ──
  await CrashReporter.init(appConfig);

  // ── 5. Initialize data-layer DI (GetIt) — NOT MODIFIED ──
  await initDependencies();

  // ── 5b. Detect base URL change → clear stale session ──
  await _clearIfBaseUrlChanged(appConfig.baseUrl);

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
