import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/models/attendance_models.dart';
import '../providers/attendance_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for check-in/out errors and show dialog/snackbar.
    ref.listen<CheckActionState>(checkActionProvider, (prev, next) {
      final error = next.error;
      if (error != null) {
        GlobalErrorHandler.show(context, error);
        ref.read(checkActionProvider.notifier).clearError();
      }

      // Success: show a simple snackbar.
      if (next.record != null && (prev?.record?.id != next.record!.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance record updated successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    final checkAction = ref.watch(checkActionProvider);

    final historyState = ref.watch(attendanceHistoryProvider);
    final historyController = ref.read(attendanceHistoryProvider.notifier);
    final summary = historyController.summary;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          // ── Gradient Header ──
          CustomAppBar(
            title: 'Attendance'.tr(context),
            subtitle: 'Attendance summary — current month'.tr(context),
            onRefresh: () => ref.read(attendanceHistoryProvider.notifier).refresh(),
          ),

          const SizedBox(height: 8),

          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SummaryCard(summary: summary),
            ),

          const SizedBox(height: 12),

          Expanded(
            child: PaginatedListView<AttendanceRecord>(
              state: historyState,
              onRefresh: () =>
                  ref.read(attendanceHistoryProvider.notifier).refresh(),
              onLoadMore: () =>
                  ref.read(attendanceHistoryProvider.notifier).loadMore(),
              itemBuilder: (context, record) => _RecordTile(record: record),
              emptyIcon: null,
              emptyTitle: '',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AttendanceSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
              label: 'Present'.tr(context),
              value: '${summary.presentDays}',
              color: AppColors.success),
          _Stat(
              label: 'Absent'.tr(context),
              value: '${summary.absentDays}',
              color: AppColors.error),
          _Stat(
              label: 'Late'.tr(context),
              value: '${summary.lateDays}',
              color: AppColors.warning),
          _Stat(
              label: 'Leave'.tr(context),
              value: '${summary.leaveDays}',
              color: AppColors.info),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

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
            style: TextStyle(fontFamily: 'Cairo',fontSize: 11, color: context.appColors.textMuted)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AttendanceRecord record;
  const _RecordTile({required this.record});

  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'approved';
      case 'absent':
        return 'rejected';
      case 'late':
        return 'pending';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'late':
        return 'Late';
      case 'leave':
        return 'Leave';
      default:
        return status;
    }
  }

  String _formatWorkedHours(BuildContext context, double hours) {
    final h = hours.truncate();
    final m = ((hours - h) * 60).round();
    final hLabel = 'h'.tr(context);
    final mLabel = 'm'.tr(context);
    if (m == 0) return '\u200F$h $hLabel';
    return '\u200F$h $hLabel $m $mLabel';
  }

  void _showDetailSheet(BuildContext context) {
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
                    record.date,
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  text: _statusLabel(record.status).tr(context),
                  type: _statusType(record.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Rows ──
            _AttendanceDetailRow(
              icon: '📊',
              label: 'Status'.tr(context),
              value: _statusLabel(record.status).tr(context),
            ),
            if (record.checkInTime != null)
              _AttendanceDetailRow(
                icon: '▶',
                label: 'Check in'.tr(context),
                value: AppFuns.formatApiDateTime(record.checkInTime!, withSeconds: true, isAr: Localizations.localeOf(context).languageCode == 'ar'),
              ),
            if (record.checkOutTime != null)
              _AttendanceDetailRow(
                icon: '⏹',
                label: 'Check out'.tr(context),
                value: AppFuns.formatApiDateTime(record.checkOutTime!, withSeconds: true, isAr: Localizations.localeOf(context).languageCode == 'ar'),
              ),
            _AttendanceDetailRow(
              icon: '⏱',
              label: 'Worked hours'.tr(context),
              value: record.workedHours.toStringAsFixed(1),
            ),
            if (record.overtimeMinutes > 0)
              _AttendanceDetailRow(
                icon: '⏰',
                label: 'Overtime'.tr(context),
                value: '${record.overtimeMinutes} ${'min'.tr(context)}',
              ),
            if (record.lateMinutes > 0)
              _AttendanceDetailRow(
                icon: '⚠',
                label: 'Late'.tr(context),
                value: '${record.lateMinutes} ${'min'.tr(context)}',
              ),
            if (record.earlyDepartureMinutes > 0)
              _AttendanceDetailRow(
                icon: '🚪',
                label: 'Early departure'.tr(context),
                value: '${record.earlyDepartureMinutes} ${'min'.tr(context)}',
              ),
            if (record.shortageMinutes > 0)
              _AttendanceDetailRow(
                icon: '📉',
                label: 'Shortage'.tr(context),
                value: '${record.shortageMinutes} ${'min'.tr(context)}',
              ),
            if (record.scheduledStart != null)
              _AttendanceDetailRow(
                icon: '🕐',
                label: 'Scheduled start'.tr(context),
                value: record.scheduledStart!,
              ),
            if (record.scheduledEnd != null)
              _AttendanceDetailRow(
                icon: '🕐',
                label: 'Scheduled end'.tr(context),
                value: record.scheduledEnd!,
              ),
            if (record.checkInSource != null)
              _AttendanceDetailRow(
                icon: '📍',
                label: 'Check in source'.tr(context),
                value: record.checkInSource!,
              ),
            if (record.checkOutSource != null)
              _AttendanceDetailRow(
                icon: '📍',
                label: 'Check out source'.tr(context),
                value: record.checkOutSource!,
              ),
            if (record.notes != null && record.notes!.isNotEmpty)
              _AttendanceDetailRow(
                icon: '📝',
                label: 'Notes'.tr(context),
                value: record.notes!,
                multiLine: true,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Extracts formatted time (h:mm:ss AM/PM or ص/م) from API datetime string.
  String _extractTime(BuildContext context, String dateTimeStr) {
    try {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final utc = DateTime.parse(dateTimeStr).toUtc();
      final local = utc.toLocal();
      final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
      final period = local.hour >= 12 ? (isAr ? 'م' : 'PM') : (isAr ? 'ص' : 'AM');
      final min = local.minute.toString().padLeft(2, '0');
      final sec = local.second.toString().padLeft(2, '0');
      return AppFuns.replaceArabicNumbers('$h:$min:$sec $period');
    } catch (_) {
      return dateTimeStr;
    }
  }

  /// Builds the date label using AppFuns.formatDate (e.g. "الثلاثاء، 17-مارس-2026").
  String _buildDateLabel() {
    try {
      final d = DateTime.parse(record.date);
      return AppFuns.formatDate(d);
    } catch (_) {
      return record.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusType = record.status == 'present' ? 'success' : 'error';
    final inTime = record.checkInTime != null ? _extractTime(context, record.checkInTime!) : null;
    final outTime = record.checkOutTime != null ? _extractTime(context, record.checkOutTime!) : null;

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
            // ── Row 1: Worked hours | Date | Status ──
            Row(
              children: [
                if (record.workedHours > 0)
                  Text(
                    _formatWorkedHours(context, record.workedHours),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _buildDateLabel(),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  text: _statusLabel(record.status).tr(context),
                  type: statusType,
                  dot: true,
                ),
              ],
            ),
            // ── Row 2: Check-in time  —  Check-out time ──
            if (inTime != null || outTime != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Check in
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          inTime ?? '--:--:--',
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Check in'.tr(context),
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 10,
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '—',
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 16,
                      color: context.appColors.textMuted,
                    ),
                  ),
                  // Check out
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          outTime ?? '--:--:--',
                          style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Check out'.tr(context),
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
          ],
        ),
      ),
    );
  }
}

class _AttendanceDetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool multiLine;

  const _AttendanceDetailRow({
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
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Cairo',
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
