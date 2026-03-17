import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/providers/core_providers.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/localization/locale_provider.dart';
import 'package:hr_portal/core/theme/app_spacing.dart';
import 'package:hr_portal/core/theme/theme_mode_provider.dart';
import 'package:hr_portal/features/profile/data/models/employee_profile_model.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeMode = ref.watch(localeModeProvider);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(dashboardAttendanceProvider);
        },
        child: Column(
          children: [
            // ── Hero Header ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryMid, AppColors.primaryDeep],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 16,
                left: 18,
                right: 18,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // ── Action Buttons (Left) ──
                      Row(
                        children: [
                          _HeaderIconButton(
                            icon: '🔔',
                            onTap: () => context.push('/notifications'),
                          ),
                          const SizedBox(width: 8),
                          _HeaderIconButton(
                            icon: '⚙️',
                            onTap: () => _showSettingsSheet(
                                context, ref, themeMode, localeMode),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // ── Profile Info (Right) ──
                      Expanded(
                        child: profileAsync.when(
                          data: (profile) => _HeroProfileInfo(profile: profile),
                          loading: () => Text(
                            'Loading...'.tr(context),
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: Colors.white60),
                            textAlign: TextAlign.end,
                          ),
                          error: (_, __) => Text(
                            'Welcome'.tr(context),
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Attendance Card ──
                  ref.watch(dashboardAttendanceProvider).when(
                        data: (summary) =>
                            _AttendanceHeroCard(summary: summary),
                        loading: () => Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white54, strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (e, _) => Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Error loading attendance'.tr(context),
                                style: GoogleFonts.cairo(
                                    fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),

            // ── Scrollable Body ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ── Quick Actions ──
                  AppSectionHeader(title: 'Quick actions'.tr(context)),
                  _QuickActionsGrid(),
                  const SizedBox(height: 20),

                  // ── Attendance Summary ──
                  AppSectionHeader(
                      title:
                          'Attendance summary — current month'.tr(context)),
                  ref.watch(dashboardAttendanceProvider).when(
                        data: (summary) =>
                            _AttendanceSummaryCard(summary: summary),
                        loading: () => const SizedBox(
                            height: 80, child: LoadingIndicator()),
                        error: (e, _) => _ErrorCard(
                          error: GlobalErrorHandler.handle(e),
                          onRetry: () =>
                              ref.invalidate(dashboardAttendanceProvider),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref,
      ThemeMode themeMode, AppLocaleMode localeMode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text('Theme'.tr(context)),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                onChanged: (m) {
                  if (m != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(m);
                  }
                },
                items: [
                  DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'.tr(context))),
                  DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'.tr(context))),
                  DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'.tr(context))),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text('Language'.tr(context)),
              trailing: DropdownButton<AppLocaleMode>(
                value: localeMode,
                underline: const SizedBox(),
                onChanged: (m) {
                  if (m != null) {
                    ref.read(localeModeProvider.notifier).setMode(m);
                  }
                },
                items: [
                  DropdownMenuItem(
                      value: AppLocaleMode.system,
                      child: Text('System'.tr(context))),
                  DropdownMenuItem(
                      value: AppLocaleMode.en,
                      child: Text('English'.tr(context))),
                  DropdownMenuItem(
                      value: AppLocaleMode.ar,
                      child: Text('Arabic'.tr(context))),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text('Logout'.tr(context),
                  style: const TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showLogoutDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout'.tr(context)),
        content: Text('Do you want to log out from this device?'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text('Cancel'.tr(context)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              Navigator.of(dCtx).pop();
              try {
                final auth = ref.read(authRepositoryProvider);
                await auth.logout();
                ref.read(authProvider.notifier).onLogout();
              } catch (e) {
                if (dCtx.mounted) {
                  GlobalErrorHandler.show(dCtx, GlobalErrorHandler.handle(e));
                }
              }
            },
            child: Text('Sign out'.tr(context)),
          ),
        ],
      ),
    );
  }
}

// ── Private Widgets ──────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
      ),
    );
  }
}

class _HeroProfileInfo extends StatelessWidget {
  final EmployeeProfile profile;
  const _HeroProfileInfo({required this.profile});

  String _getGreeting(BuildContext context) {
    final now = DateTime.now();
    if (now.hour < 12) return 'Good morning'.tr(context);
    if (now.hour < 18) return 'Good afternoon'.tr(context);
    return 'Good evening'.tr(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${_getGreeting(context)}،',
          style: GoogleFonts.cairo(fontSize: 13, color: Colors.white60),
        ),
        Text(
          profile.name,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (profile.jobTitle != null)
          Text(
            profile.jobTitle!,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.goldLight),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}

class _AttendanceHeroCard extends StatelessWidget {
  final dynamic summary;
  const _AttendanceHeroCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _HeroStat(
              label: 'Present'.tr(context), value: '${summary.presentDays}'),
          _HeroStat(
              label: 'Absent'.tr(context), value: '${summary.absentDays}'),
          _HeroStat(label: 'Late'.tr(context), value: '${summary.lateDays}'),
          _HeroStat(
              label: 'Leave'.tr(context), value: '${summary.leaveDays}'),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            )),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    {'label': 'Attendance', 'icon': '⏱', 'route': '/attendance', 'color': AppColors.primaryMid},
    {'label': 'Leaves', 'icon': '🌴', 'route': '/leaves', 'color': AppColors.teal},
    {'label': 'Payroll', 'icon': '💰', 'route': '/payroll', 'color': AppColors.gold},
    {'label': 'Requests', 'icon': '📝', 'route': '/requests', 'color': AppColors.success},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.8,
      children: _actions
          .map((a) => GestureDetector(
                onTap: () => context.go(a['route'] as String),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: context.appColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.gray100),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (a['color'] as Color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(a['icon'] as String,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (a['label'] as String).tr(context),
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  final dynamic summary;
  const _AttendanceSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryStat(
              label: 'Present'.tr(context),
              value: '${summary.presentDays}',
              color: AppColors.success),
          _SummaryStat(
              label: 'Absent'.tr(context),
              value: '${summary.absentDays}',
              color: AppColors.error),
          _SummaryStat(
              label: 'Late'.tr(context),
              value: '${summary.lateDays}',
              color: AppColors.warning),
          _SummaryStat(
              label: 'Leave'.tr(context),
              value: '${summary.leaveDays}',
              color: AppColors.info),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            )),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.cairo(fontSize: 11, color: context.appColors.textMuted)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final UiError error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error.message.tr(context),
                style: GoogleFonts.cairo(
                    fontSize: 13, color: context.appColors.textSecondary)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry'.tr(context)),
          ),
        ],
      ),
    );
  }
}
