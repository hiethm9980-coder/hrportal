import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiffy/jiffy.dart';

import 'router/app_router.dart';
import 'core/providers/core_providers.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'shared/widgets/shared_widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Root application widget.
///
/// Sets up:
/// 1. [ProviderScope] for Riverpod
/// 2. [MaterialApp.router] with GoRouter
/// 3. Localization (EN default + AR)
/// 4. Session expired callback → GoRouter redirect
class HrMobileApp extends ConsumerStatefulWidget {
  const HrMobileApp({super.key});

  @override
  ConsumerState<HrMobileApp> createState() => _HrMobileAppState();
}

class _HrMobileAppState extends ConsumerState<HrMobileApp> {
  String? _jiffyLocaleCode;

  @override
  void initState() {
    super.initState();

    // Connect SessionManager's expiry callback to show dialog.
    Future.microtask(() {
      final session = ref.read(sessionManagerProvider);
      session.onSessionExpired = (message) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          SessionExpiredDialog.show(ctx);
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(resolvedLocaleProvider);
    final materialLocale = ref.watch(materialLocaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Keep Jiffy locale aligned with app locale.
    // Riverpod allows `ref.listen` only inside build. Since this widget already
    // rebuilds when locale changes, we can safely sync Jiffy here.
    if (_jiffyLocaleCode != locale.languageCode) {
      _jiffyLocaleCode = locale.languageCode;
      Jiffy.setLocale(_jiffyLocaleCode!);
    }

    return MaterialApp.router(
      title: 'HR Mobile',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],

      // ── Theme ──
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // ── Locale ──
      // System → null (follow device), EN/AR → forced.
      locale: materialLocale,
      // ── Router ──
      routerConfig: router,

      // ── Status bar: white icons on the navy gradient header ─────────
      // Every in-app header paints `AppColors.navyGradient` behind the
      // system status bar, so the clock / battery / wifi icons must be
      // white to stay readable. Wrapping MaterialApp's `builder` in an
      // AnnotatedRegion is the only reliable way — `SystemChrome` called
      // once in `main()` gets reset on every route transition.
      // Mirror layout: Arabic = RTL, English = LTR (independent of device
      // direction when locale is forced).
      builder: (context, child) {
        final textDir = locale.languageCode.toLowerCase() == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;
        return Directionality(
          textDirection: textDir,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light, // Android
              statusBarBrightness: Brightness.dark,       // iOS
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
