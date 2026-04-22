import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
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
    final profileAsync = ref.watch(profileProvider);

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
                      // ── Profile Info (start side) — tap to open profile ──
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/profile'),
                          behavior: HitTestBehavior.opaque,
                          child: profileAsync.when(
                            data: (profile) => _HeroProfileInfo(profile: profile),
                            loading: () => Text(
                              'Loading...'.tr(context),
                              style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 13, color: Colors.white60),
                              textAlign: TextAlign.start,
                            ),
                            error: (_, _) => Text(
                              'Welcome'.tr(context),
                              style: TextStyle(fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Action Buttons (end side) ──
                      Row(
                        children: [
                          _HeaderIconButton(
                            icon: '⚙️',
                            onTap: () => context.push('/settings'),
                          ),
                          const SizedBox(width: 8),
                          _HeaderIconButton(
                            icon: '🔔',
                            onTap: () => context.push('/notifications'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),


                  // // ── Attendance Card ──
                  // ref.watch(dashboardAttendanceProvider).when(
                  //       data: (summary) =>
                  //           _AttendanceHeroCard(summary: summary),
                  //       loading: () => Container(
                  //         padding: const EdgeInsets.all(14),
                  //         decoration: BoxDecoration(
                  //           color: Colors.white10,
                  //           borderRadius: BorderRadius.circular(16),
                  //           border: Border.all(color: Colors.white24),
                  //         ),
                  //         child: const Center(
                  //           child: SizedBox(
                  //             width: 24,
                  //             height: 24,
                  //             child: CircularProgressIndicator(
                  //                 color: Colors.white54, strokeWidth: 2),
                  //           ),
                  //         ),
                  //       ),
                  //       error: (e, _) => Container(
                  //         padding: const EdgeInsets.all(14),
                  //         decoration: BoxDecoration(
                  //           color: Colors.white10,
                  //           borderRadius: BorderRadius.circular(16),
                  //           border: Border.all(color: Colors.white24),
                  //         ),
                  //         child: Row(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           children: [
                  //             const Icon(Icons.error_outline,
                  //                 color: Colors.white54, size: 18),
                  //             const SizedBox(width: 8),
                  //             Text(
                  //               'Error loading attendance'.tr(context),
                  //               style: TextStyle(fontFamily: 'Cairo',
                  //                   fontSize: 12, color: Colors.white54),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
               
               ],
              ),
            ),

            // ── Scrollable Body ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                children: [
                  // ── Quick Actions ──
                  AppSectionHeader(title: 'Quick actions'.tr(context)),
                  const SizedBox(height: 12),
                  _QuickActionsGrid(),
                  const SizedBox(height: 24),

                  // ── Attendance Summary ──
                  AppSectionHeader(
                      title:
                          'Attendance summary — current month'.tr(context)),
                  const SizedBox(height: 12),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(context),
              style: TextStyle(fontFamily: 'Cairo',fontSize: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('👋', style: TextStyle(fontSize: 16)),
          ],
        ),
        Text(
          profile.name,
          style: TextStyle(fontFamily: 'Cairo',
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
            style: TextStyle(fontFamily: 'Cairo',fontSize: 11, color: AppColors.goldLight),
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
            style: TextStyle(fontFamily: 'Cairo',fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            )),
      ],
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  static const _baseActions = [
    {'label': 'Attendance', 'icon': '⏱', 'route': '/attendance', 'color': AppColors.primaryMid},
    {'label': 'Leaves', 'icon': '🌴', 'route': '/leaves', 'color': AppColors.teal},
    {'label': 'Payroll', 'icon': '💰', 'route': '/payroll', 'color': AppColors.gold},
    {'label': 'Requests', 'icon': '📝', 'route': '/requests', 'color': AppColors.success},
    {'label': 'My Tasks', 'icon': '📋', 'route': '/my-tasks', 'color': AppColors.primaryLight},
  ];

  static const _approvalAction = {
    'label': 'Approvals',
    'icon': '✅',
    'route': '/approvals',
    'color': AppColors.info,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final actions = [
      ..._baseActions,
      if (auth.isManager) 
        _approvalAction,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const spacing = 10.0;
        // Calculate item width: fit 4 per row minimum, more if space allows
        final itemsPerRow = (totalWidth + spacing) ~/ (80 + spacing);
        final columns = itemsPerRow.clamp(3, 6);
        final itemWidth =
            (totalWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((a) => GestureDetector(
                    // Push (not go) so Android/iOS system Back returns to the
                    // dashboard instead of exiting the app.
                    onTap: () => context.push(a['route'] as String),
                    child: SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        decoration: BoxDecoration(
                          color: context.appColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: context.appColors.gray100),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    (a['color'] as Color).withOpacity(0.12),
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
                              style: TextStyle(fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.appColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
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
            style: TextStyle(fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            )),
        const SizedBox(height: 4),
        Text(label,
            style:
                TextStyle(fontFamily: 'Cairo',fontSize: 11, color: context.appColors.textMuted)),
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
                style: TextStyle(fontFamily: 'Cairo',
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
