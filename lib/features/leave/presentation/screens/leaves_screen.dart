import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/theme/app_spacing.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/leave_providers.dart';

class LeavesScreen extends ConsumerWidget {
  const LeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leavesListProvider);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          // ── Gradient Header ──
          CustomAppBar(
            title: 'Leaves'.tr(context),
            onRefresh: () => ref.read(leavesListProvider.notifier).refresh(),
            leading: GestureDetector(
              onTap: () => context.go('/leaves/create'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: state.isLoading
                ? const Center(child: LoadingIndicator())
                : state.error != null
                    ? ErrorFullScreen(
                        error: state.error!,
                        onRetry: () =>
                            ref.read(leavesListProvider.notifier).refresh(),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(leavesListProvider.notifier).refresh(),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            AppSectionHeader(title: 'Balance'.tr(context)),
                            if (state.balances.isEmpty)
                              EmptyStateWidget(
                                icon: '📊',
                                title: 'No available balance'.tr(context),
                              )
                            else
                              SizedBox(
                                height: 110,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: state.balances.map((b) {
                                    final avail = b.available;
                                    return Container(
                                      width: 130,
                                      margin: const EdgeInsetsDirectional.only(end: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: context.appColors.bgCard,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        boxShadow: AppShadows.card,
                                        border: const Border(
                                          top: BorderSide(
                                              color: AppColors.teal, width: 3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.leaveType?.name ?? '',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: context.appColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${avail.toStringAsFixed(1)}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.teal,
                                              height: 1.1,
                                            ),
                                          ),
                                          Text(
                                            '${'Used'.tr(context)}: ${b.used.toStringAsFixed(1)}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 10,
                                              color: context.appColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                            const SizedBox(height: 20),
                            AppSectionHeader(title: 'Requests'.tr(context)),
                            if (state.requests.isEmpty)
                              EmptyStateWidget(
                                icon: '📋',
                                title: 'No leave requests'.tr(context),
                              )
                            else
                              ...state.requests.map(
                                (r) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.appColors.bgCard,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.leaveType?.name ?? '',
                                            style: GoogleFonts.cairo(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${r.startDate} → ${r.endDate}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              color: context.appColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${r.totalDays.toStringAsFixed(1)} ${'day'.tr(context)}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              color: context.appColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            text: r.status,
                                            type: _statusType(r.status),
                                            dot: true,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
        return 'pending';
      default:
        return 'info';
    }
  }
}
