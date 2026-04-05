import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/localization/locale_provider.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/theme/theme_mode_provider.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final localeMode = ref.watch(localeModeProvider);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          // ── Header ──
          CustomAppBar(
            title: 'Settings'.tr(context),
            onBack: () => context.pop(),
          ),

          // ── Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ══════════ Theme Section ══════════
                _SectionHeader(
                  icon: Icons.brightness_6_outlined,
                  title: 'Theme'.tr(context),
                ),
                const SizedBox(height: 8),
                _OptionCard(
                  children: [
                    _RadioOption<ThemeMode>(
                      label: 'System'.tr(context),
                      icon: Icons.settings_suggest_outlined,
                      value: ThemeMode.system,
                      groupValue: themeMode,
                      onChanged: (v) =>
                          ref.read(themeModeProvider.notifier).setThemeMode(v),
                    ),
                    _divider(context),
                    _RadioOption<ThemeMode>(
                      label: 'Light'.tr(context),
                      icon: Icons.light_mode_outlined,
                      value: ThemeMode.light,
                      groupValue: themeMode,
                      onChanged: (v) =>
                          ref.read(themeModeProvider.notifier).setThemeMode(v),
                    ),
                    _divider(context),
                    _RadioOption<ThemeMode>(
                      label: 'Dark'.tr(context),
                      icon: Icons.dark_mode_outlined,
                      value: ThemeMode.dark,
                      groupValue: themeMode,
                      onChanged: (v) =>
                          ref.read(themeModeProvider.notifier).setThemeMode(v),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ══════════ Language Section ══════════
                _SectionHeader(
                  icon: Icons.language,
                  title: 'Language'.tr(context),
                ),
                const SizedBox(height: 8),
                _OptionCard(
                  children: [
                    _RadioOption<AppLocaleMode>(
                      label: 'System'.tr(context),
                      icon: Icons.phone_android_outlined,
                      value: AppLocaleMode.system,
                      groupValue: localeMode,
                      onChanged: (v) =>
                          ref.read(localeModeProvider.notifier).setMode(v),
                    ),
                    _divider(context),
                    _RadioOption<AppLocaleMode>(
                      label: 'English'.tr(context),
                      icon: null,
                      flagText: 'EN',
                      value: AppLocaleMode.en,
                      groupValue: localeMode,
                      onChanged: (v) =>
                          ref.read(localeModeProvider.notifier).setMode(v),
                    ),
                    _divider(context),
                    _RadioOption<AppLocaleMode>(
                      label: 'Arabic'.tr(context),
                      icon: null,
                      flagText: 'AR',
                      value: AppLocaleMode.ar,
                      groupValue: localeMode,
                      onChanged: (v) =>
                          ref.read(localeModeProvider.notifier).setMode(v),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Logout Button (fixed at bottom) ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _showLogoutDialog(context, ref),
                  icon: const Icon(Icons.logout, size: 20),
                  label: Text(
                    'Logout'.tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout'.tr(context),
            style: TextStyle(fontFamily: 'Cairo',fontWeight: FontWeight.w700)),
        content: Text('Do you want to log out from this device?'.tr(context),
            style: TextStyle(fontFamily: 'Cairo',)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text('Cancel'.tr(context), style: TextStyle(fontFamily: 'Cairo',)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(dCtx).pop();
              try {
                final auth = ref.read(authRepositoryProvider);
                await auth.logout();
                ref.read(authProvider.notifier).onLogout();
              } catch (e) {
                if (dCtx.mounted) {
                  GlobalErrorHandler.show(
                      dCtx, GlobalErrorHandler.handle(e));
                }
              }
            },
            child: Text('Sign out'.tr(context), style: TextStyle(fontFamily: 'Cairo',)),
          ),
        ],
      ),
    );
  }

  static Widget _divider(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: context.appColors.gray200,
      );
}

// ═══════════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryMid),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.appColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Option Card (container for radio options)
// ═══════════════════════════════════════════════════════════════════

class _OptionCard extends StatelessWidget {
  final List<Widget> children;
  const _OptionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Radio Option
// ═══════════════════════════════════════════════════════════════════

class _RadioOption<T> extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? flagText;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  const _RadioOption({
    required this.label,
    this.icon,
    this.flagText,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Material(
      color: isSelected
          ? AppColors.primaryMid.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Leading icon or flag
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryMid
                      : context.appColors.textMuted,
                ),
              if (flagText != null)
                Container(
                  width: 28,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryMid.withValues(alpha: 0.1)
                        : context.appColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    flagText!,
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.primaryMid
                          : context.appColors.textMuted,
                    ),
                  ),
                ),
              const SizedBox(width: 12),

              // Label
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryMid
                        : context.appColors.textPrimary,
                  ),
                ),
              ),

              // Radio indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryMid
                        : context.appColors.textMuted,
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryMid,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
