import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/localization/locale_provider.dart';
import 'package:hr_portal/core/theme/theme_mode_provider.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';
import 'package:pwa_install/pwa_install.dart';

import '../../../../shared/controllers/global_error_handler.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(loginFormProvider);
    final notifier = ref.read(loginFormProvider.notifier);
    final localeMode = ref.watch(localeModeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Show error snackbar/dialog when error changes.
    ref.listen<LoginFormState>(loginFormProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        if (next.error!.action != ErrorAction.showFieldErrors) {
          GlobalErrorHandler.show(context, next.error!);
        }
      }
    });

    String getLocaleName(AppLocaleMode mode) {
      switch (mode) {
        case AppLocaleMode.system:
          return 'System'.tr(context);
        case AppLocaleMode.en:
          return 'English'.tr(context);
        case AppLocaleMode.ar:
          return 'Arabic'.tr(context);
      }
    }

    String getThemeName(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.system:
          return 'System'.tr(context);
        case ThemeMode.light:
          return 'Light'.tr(context);
        case ThemeMode.dark:
          return 'Dark'.tr(context);
      }
    }

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Gradient Header ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryMid, AppColors.primaryDeep],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 32,
                bottom: 40,
                left: 22,
                right: 22,
              ),
              child: Column(
                children: [
                  const Text('🏢', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome'.tr(context),
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employee Self Service Portal'.tr(context),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Body ──
            Padding(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Language / Theme Selectors ──
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SettingChip(
                          icon: Icons.brightness_6_outlined,
                          label:
                              "${'Theme'.tr(context)} (${getThemeName(themeMode)})",
                          items: [
                            PopupMenuItem(
                              value: ThemeMode.system,
                              child: Text('System'.tr(context)),
                            ),
                            PopupMenuItem(
                              value: ThemeMode.light,
                              child: Text('Light'.tr(context)),
                            ),
                            PopupMenuItem(
                              value: ThemeMode.dark,
                              child: Text('Dark'.tr(context)),
                            ),
                          ],
                          onSelected: (m) => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(m as ThemeMode),
                        ),
                        _SettingChip(
                          icon: Icons.language,
                          label:
                              "${'Language'.tr(context)} (${getLocaleName(localeMode)})",
                          items: [
                            PopupMenuItem(
                              value: AppLocaleMode.system,
                              child: Text('System'.tr(context)),
                            ),
                            PopupMenuItem(
                              value: AppLocaleMode.en,
                              child: Text('English'.tr(context)),
                            ),
                            PopupMenuItem(
                              value: AppLocaleMode.ar,
                              child: Text('Arabic'.tr(context)),
                            ),
                          ],
                          onSelected: (m) => ref
                              .read(localeModeProvider.notifier)
                              .setMode(m as AppLocaleMode),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Username Label ──
                    Text(
                      'Email or username'.tr(context),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: notifier.setUsername,
                      enabled: !form.isLoading,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.cairo(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Email or username'.tr(context),
                        errorText: form.fieldError('username'),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Password Label ──
                    Text(
                      'Password'.tr(context),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: notifier.setPassword,
                      enabled: !form.isLoading,
                      obscureText: form.obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: GoogleFonts.cairo(fontSize: 13),
                      onSubmitted: (_) {
                        if (form.canSubmit) notifier.submit();
                      },
                      decoration: InputDecoration(
                        hintText: 'Password'.tr(context),
                        errorText: form.fieldError('password'),
                        suffixIcon: IconButton(
                          onPressed: notifier.togglePasswordVisibility,
                          icon: Icon(
                            form.obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: context.appColors.gray400,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Submit Button ──
                    PrimaryButton(
                      text: 'Login'.tr(context),
                      loading: form.isLoading,
                      onTap: form.canSubmit
                          ? () {
                              if (PWAInstall().installPromptEnabled) {
                                PWAInstall().promptInstall_();
                              }
                              notifier.submit();
                            }
                          : null,
                    ),

                    // ── General Error ──
                    if (form.error != null &&
                        form.error!.action == ErrorAction.showFieldErrors)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            form.error!.message,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.errorDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small chip-style popup button for settings (theme, language).
class _SettingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<PopupMenuEntry> items;
  final Function(dynamic) onSelected;

  const _SettingChip({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.gray200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryMid),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16, color: context.appColors.gray400),
          ],
        ),
      ),
    );
  }
}
