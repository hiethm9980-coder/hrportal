import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
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
                        child: _buildList(context, state),
                      ),
          ),
        ],
      ),
    );
  }

  /// Build the flat item list for ListView.separated
  List<Widget> _buildItems(BuildContext context, dynamic state) {
    final items = <Widget>[];

    // ── Balance Section Header ──
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppSectionHeader(title: 'Balance'.tr(context)),
      ),
    );

    // ── Balance Cards or Empty ──
    if (state.balances.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EmptyStateWidget(
            icon: '📊',
            title: 'No available balance'.tr(context),
          ),
        ),
      );
    } else {
      items.add(
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            itemCount: state.balances.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final b = state.balances[index];
              final avail = b.available;
              return Container(
                width: 120,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                  border: const Border(
                    top: BorderSide(color: AppColors.teal, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      avail.toStringAsFixed(1),
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
            },
          ),
        ),
      );
    }

    // ── Requests Section Header ──
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppSectionHeader(title: 'Requests'.tr(context)),
      ),
    );

    // ── Request Items or Empty ──
    if (state.requests.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EmptyStateWidget(
            icon: '📋',
            title: 'No leave requests'.tr(context),
          ),
        ),
      );
    } else {
      for (final r in state.requests) {
        final startFormatted = _formatLeaveDate(r.startDate);
        final endFormatted = _formatLeaveDate(r.endDate);
        final days = r.totalDays;
        final daysLabel = days == days.truncateToDouble()
            ? '${days.toInt()} ${'d'.tr(context)}'
            : '${days.toStringAsFixed(1)} ${'d'.tr(context)}';

        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showLeaveDetailSheet(context, r),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    // ── Row 1: Status | Leave type (centered) | Days ──
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Text(
                            r.leaveType?.name ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.appColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              daysLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.teal,
                              ),
                            ),
                            StatusBadge(
                              text: _statusLabel(r.status).tr(context),
                              type: _statusType(r.status),
                              dot: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Row 2: From date — To date ──
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  startFormatted,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'From'.tr(context),
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: context.appColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '—',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: context.appColors.textMuted,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  endFormatted,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'To'.tr(context),
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: context.appColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ── Row 3: Created at ──
                    const SizedBox(height: 6),
                    Text(
                      _formatLeaveDate(r.createdAt.substring(0, 10)),
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return items;
  }

  Widget _buildList(BuildContext context, dynamic state) {
    final items = _buildItems(context, state);

    // Fixed layout:
    // 0 = Balance header
    // 1 = Balance content
    // 2 = Requests header
    // 3+ = Request items
    final requestsHeaderIndex = 2;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      itemCount: items.length,
      separatorBuilder: (_, index) {
        // After section headers → title-to-content gap
        if (index == 0 || index == requestsHeaderIndex) {
          return const SizedBox(height: 12);
        }
        // Between balance content and requests header → section gap
        if (index == requestsHeaderIndex - 1) {
          return const SizedBox(height: 24);
        }
        // Between request items
        return const SizedBox(height: 10);
      },
      itemBuilder: (_, index) => items[index],
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  String _dayPartLabel(String dayPart) {
    switch (dayPart.toLowerCase()) {
      case 'full':
        return 'Full day';
      case 'first_half':
        return 'First half';
      case 'second_half':
        return 'Second half';
      default:
        return dayPart;
    }
  }

  void _showLeaveDetailSheet(BuildContext context, dynamic r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.appColors.bgCard,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title & Status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: 10, top: 2),
                    child: Icon(Icons.close,
                        size: 22, color: context.appColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.leaveType?.name ?? 'Leave'.tr(context),
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  text: _statusLabel(r.status).tr(context),
                  type: _statusType(r.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Rows ──
            _LeaveDetailRow(
              icon: '📅',
              label: 'From'.tr(context),
              value: r.startDate,
            ),
            _LeaveDetailRow(
              icon: '📅',
              label: 'To'.tr(context),
              value: r.endDate,
            ),
            _LeaveDetailRow(
              icon: '⏱',
              label: 'Total days'.tr(context),
              value: '${r.totalDays.toStringAsFixed(1)} ${'day'.tr(context)}',
            ),
            _LeaveDetailRow(
              icon: '🕐',
              label: 'Day part'.tr(context),
              value: _dayPartLabel(r.dayPart).tr(context),
            ),
            _LeaveDetailRow(
              icon: '📆',
              label: 'Created at'.tr(context),
              value: AppFuns.formatApiDateTime(r.createdAt, isAr: Localizations.localeOf(context).languageCode == 'ar'),
            ),
            if (r.reason != null && r.reason!.isNotEmpty)
              _LeaveDetailRow(
                icon: '📝',
                label: 'Reason'.tr(context),
                value: r.reason!,
                multiLine: true,
              ),
            if (r.rejectionReason != null && r.rejectionReason!.isNotEmpty)
              _LeaveDetailRow(
                icon: '❌',
                label: 'Rejection reason'.tr(context),
                value: r.rejectionReason!,
                multiLine: true,
              ),
            if (r.approvedAt != null)
              _LeaveDetailRow(
                icon: '✅',
                label: 'Approved at'.tr(context),
                value: AppFuns.formatApiDateTime(r.approvedAt!, isAr: Localizations.localeOf(context).languageCode == 'ar'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatLeaveDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return AppFuns.formatDate(d);
    } catch (_) {
      return dateStr;
    }
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

class _LeaveDetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool multiLine;

  const _LeaveDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: multiLine ? 10 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
