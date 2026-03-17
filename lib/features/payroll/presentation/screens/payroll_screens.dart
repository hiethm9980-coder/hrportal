import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../data/models/payroll_models.dart';
import '../providers/payroll_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// Payroll List Screen
// ═══════════════════════════════════════════════════════════════════

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Payroll'.tr(context),
            onRefresh: () => ref.read(payslipListProvider.notifier).refresh(),
          ),
          Expanded(
            child: PaginatedListView<Payslip>(
              state: ref.watch(payslipListProvider),
              onRefresh: () =>
                  ref.read(payslipListProvider.notifier).refresh(),
              onLoadMore: () =>
                  ref.read(payslipListProvider.notifier).loadMore(),
              emptyIcon: Icons.receipt_long,
              emptyTitle: 'No payslips'.tr(context),
              itemBuilder: (context, payslip) =>
                  _PayslipTile(payslip: payslip),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  final Payslip payslip;
  const _PayslipTile({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final period = payslip.periodStart != null &&
            payslip.periodStart!.length >= 7
        ? payslip.periodStart!.substring(0, 7)
        : 'Unknown'.tr(context);

    return GestureDetector(
      onTap: () {
        if (payslip.periodStart != null && payslip.periodStart!.length >= 7) {
          final month = payslip.periodStart!.substring(0, 7);
          context.go('/payroll/$month');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const StatusBadge(text: '💰', type: 'gold'),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'Net'.tr(context)}: ${payslip.totalNet.toStringAsFixed(2)}',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMid,
                      ),
                    ),
                    if (payslip.currency != null)
                      Text(
                        payslip.currency!,
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: context.appColors.textMuted),
                      ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${'Period'.tr(context)} $period',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${'Gross'.tr(context)}: ${payslip.totalGross.toStringAsFixed(2)}',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: context.appColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Payslip Detail Screen
// ═══════════════════════════════════════════════════════════════════

class PayslipDetailScreen extends ConsumerWidget {
  final String month;
  const PayslipDetailScreen({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(payslipDetailProvider(month));

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Payslip — {month}'.tr(context, params: {'month': month}),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: detailAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorFullScreen(
                error: GlobalErrorHandler.handle(e),
                onRetry: () =>
                    ref.invalidate(payslipDetailProvider(month)),
              ),
              data: (payslip) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Hero Salary Card ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primaryDeep],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppShadows.navy,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net pay'.tr(context),
                                style: GoogleFonts.cairo(
                                    fontSize: 11, color: Colors.white60)),
                            Text(month,
                                style: GoogleFonts.cairo(
                                    fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          payslip.totalNet.toStringAsFixed(2),
                          style: GoogleFonts.cairo(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (payslip.currency != null)
                          Text(payslip.currency!,
                              style: GoogleFonts.cairo(
                                  fontSize: 14, color: AppColors.goldLight)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Summary Card ──
                  AppCard(
                    child: Column(
                      children: [
                        InfoRow(
                            label: 'Total gross'.tr(context),
                            value: payslip.totalGross.toStringAsFixed(2),
                            icon: '💵'),
                        InfoRow(
                            label: 'Deductions'.tr(context),
                            value: payslip.totalDeductions.toStringAsFixed(2),
                            icon: '📉'),
                        InfoRow(
                            label: 'Net pay'.tr(context),
                            value: payslip.totalNet.toStringAsFixed(2),
                            icon: '💰',
                            showBorder: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Lines ──
                  if (payslip.lines != null && payslip.lines!.isNotEmpty) ...[
                    AppSectionHeader(title: 'Details'.tr(context)),
                    ...payslip.lines!.map((line) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.sm,
                            border: Border(
                              right: BorderSide(
                                color: line.isEarning
                                    ? AppColors.success
                                    : AppColors.error,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${line.isEarning ? '+' : '-'}${line.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: line.isEarning
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  line.ruleName ??
                                      line.ruleCode ??
                                      'Item'.tr(context),
                                  style: GoogleFonts.cairo(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  // ── Meta ──
                  if (payslip.paymentMethod != null ||
                      payslip.paidAt != null) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        children: [
                          if (payslip.paymentMethod != null)
                            InfoRow(
                                label: 'Payment method'.tr(context),
                                value: payslip.paymentMethod!,
                                icon: '🏦',
                                showBorder: payslip.paidAt != null),
                          if (payslip.paidAt != null)
                            InfoRow(
                                label: 'Paid at'.tr(context),
                                value: payslip.paidAt!,
                                icon: '📅',
                                showBorder: false),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
