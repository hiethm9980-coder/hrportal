import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jiffy/jiffy.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
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

  void _showDetailSheet(BuildContext context) {
    final month = payslip.periodStart != null &&
            payslip.periodStart!.length >= 7
        ? payslip.periodStart!.substring(0, 7)
        : null;
    if (month == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.appColors.bgCard,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => Consumer(
          builder: (ctx, ref, _) {
            final detailAsync = ref.watch(payslipDetailProvider(month));
            return Column(
              children: [
                // ── Handle + Close ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.appColors.gray200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.close,
                                size: 22,
                                color: context.appColors.textMuted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Payslip — {month}'.tr(context,
                                  params: {'month': _formatPeriodMonth(payslip.periodStart)}),
                              style: TextStyle(fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.appColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Content ──
                Expanded(
                  child: detailAsync.when(
                    loading: () => const Center(child: LoadingIndicator()),
                    error: (e, _) => Center(
                      child: ErrorFullScreen(
                        error: GlobalErrorHandler.handle(e),
                        onRetry: () =>
                            ref.invalidate(payslipDetailProvider(month)),
                      ),
                    ),
                    data: (ps) => ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        // ── Hero Salary Card ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryLight,
                                AppColors.primaryDeep
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppShadows.navy,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Net pay'.tr(context),
                                      style: TextStyle(fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: Colors.white60)),
                                  Text(_formatPeriodMonth(payslip.periodStart),
                                      style: TextStyle(fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ps.totalNet.toStringAsFixed(2),
                                style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              if (ps.currency != null)
                                Text(ps.currency!,
                                    style: TextStyle(fontFamily: 'Cairo',
                                        fontSize: 14,
                                        color: AppColors.goldLight)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Summary Card ──
                        AppCard(
                          child: Column(
                            children: [
                              InfoRow(
                                  label: 'Total gross'.tr(context),
                                  value: ps.totalGross.toStringAsFixed(2),
                                  icon: '💵'),
                              InfoRow(
                                  label: 'Deductions'.tr(context),
                                  value:
                                      ps.totalDeductions.toStringAsFixed(2),
                                  icon: '📉'),
                              InfoRow(
                                  label: 'Net pay'.tr(context),
                                  value: ps.totalNet.toStringAsFixed(2),
                                  icon: '💰',
                                  showBorder: false),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Lines ──
                        if (ps.lines != null &&
                            ps.lines!.isNotEmpty) ...[
                          AppSectionHeader(title: 'Details'.tr(context)),
                          const SizedBox(height: 12),
                          ...ps.lines!.map((line) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.appColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: BorderDirectional(
                                    start: BorderSide(
                                      color: line.isEarning
                                          ? AppColors.success
                                          : AppColors.error,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        line.ruleName ??
                                            line.ruleCode ??
                                            'Item'.tr(context),
                                        style: TextStyle(fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      '${line.isEarning ? '+' : '-'}${line.amount.toStringAsFixed(2)}',
                                      style: TextStyle(fontFamily: 'Cairo',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: line.isEarning
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],

                        // ── Meta ──
                        if (ps.paymentMethod != null ||
                            ps.paidAt != null) ...[
                          const SizedBox(height: 24),
                          AppCard(
                            child: Column(
                              children: [
                                if (ps.paymentMethod != null)
                                  InfoRow(
                                      label: 'Payment method'.tr(context),
                                      value: ps.paymentMethod!,
                                      icon: '🏦',
                                      showBorder: ps.paidAt != null),
                                if (ps.paidAt != null)
                                  InfoRow(
                                      label: 'Paid at'.tr(context),
                                      value: ps.paidAt!,
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
            );
          },
        ),
      ),
    );
  }

  String _formatPeriodMonth(String? dateStr) {
    if (dateStr == null || dateStr.length < 7) return dateStr ?? '';
    try {
      final d = DateTime.parse(dateStr.substring(0, 10));
      return AppFuns.replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'MMMM yyyy'),
      );
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final netFormatted = AppFuns.replaceArabicNumbers(
        payslip.totalNet.toStringAsFixed(2));
    final grossFormatted = AppFuns.replaceArabicNumbers(
        payslip.totalGross.toStringAsFixed(2));
    final deductionsFormatted = AppFuns.replaceArabicNumbers(
        payslip.totalDeductions.toStringAsFixed(2));
    final currencyLabel = payslip.currency ?? '';

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // ── Row 1: Net pay (center, big) ──
            Text(
              '$netFormatted $currencyLabel',
              style: TextStyle(fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryMid,
              ),
            ),
            Text(
              'Net pay'.tr(context),
              style: TextStyle(fontFamily: 'Cairo',
                fontSize: 10,
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            // ── Row 2: Gross | Month | Deductions ──
            Stack(
              alignment: Alignment.center,
              children: [
                if (payslip.periodStart != null)
                  Center(
                    child: Text(
                      _formatPeriodMonth(payslip.periodStart),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$grossFormatted $currencyLabel',
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total gross'.tr(context),
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 10,
                              color: context.appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Spacer for the month in the center
                    const SizedBox(width: 80),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$deductionsFormatted $currencyLabel',
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Deductions'.tr(context),
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 10,
                              color: context.appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  String _formatMonth(String monthStr) {
    try {
      final d = DateTime.parse('$monthStr-01');
      return AppFuns.replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'MMMM yyyy'),
      );
    } catch (_) {
      return monthStr;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(payslipDetailProvider(month));

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Payslip — {month}'.tr(context, params: {'month': _formatMonth(month)}),
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
                                style: TextStyle(fontFamily: 'Cairo',
                                    fontSize: 11, color: Colors.white60)),
                            Text(_formatMonth(month),
                                style: TextStyle(fontFamily: 'Cairo',
                                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          payslip.totalNet.toStringAsFixed(2),
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (payslip.currency != null)
                          Text(payslip.currency!,
                              style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 14, color: AppColors.goldLight)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 24),

                  // ── Lines ──
                  if (payslip.lines != null && payslip.lines!.isNotEmpty) ...[
                    AppSectionHeader(title: 'Details'.tr(context)),
                    const SizedBox(height: 12),
                    ...payslip.lines!.map((line) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.sm,
                            border: BorderDirectional(
                              start: BorderSide(
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
                              Flexible(
                                child: Text(
                                  line.ruleName ??
                                      line.ruleCode ??
                                      'Item'.tr(context),
                                  style: TextStyle(fontFamily: 'Cairo',
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${line.isEarning ? '+' : '-'}${line.amount.toStringAsFixed(2)}',
                                style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: line.isEarning
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  // ── Meta ──
                  if (payslip.paymentMethod != null ||
                      payslip.paidAt != null) ...[
                    const SizedBox(height: 24),
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
