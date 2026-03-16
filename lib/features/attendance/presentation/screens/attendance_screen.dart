import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/theme/app_spacing.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

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
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Gradient Header ──
          CustomAppBar(
            title: 'Attendance'.tr(context),
            subtitle: 'Attendance summary — current month'.tr(context),
          ),

          // ── Check In / Out Buttons ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TealButton(
                    text: 'Check in'.tr(context),
                    icon: '▶',
                    small: true,
                    onTap: checkAction.isLoading
                        ? null
                        : () => ref.read(checkActionProvider.notifier).checkIn(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppOutlineButton(
                    text: 'Check out'.tr(context),
                    color: AppColors.error,
                    small: true,
                    onTap: checkAction.isLoading
                        ? null
                        : () => ref.read(checkActionProvider.notifier).checkOut(),
                  ),
                ),
              ],
            ),
          ),

          if (checkAction.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(color: AppColors.primaryMid),
            ),

          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SummaryCard(summary: summary),
            ),

          const SizedBox(height: 8),

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
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AttendanceRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusType = record.status == 'present' ? 'success' : 'error';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatusBadge(text: record.status, type: statusType, dot: true),
              if (record.checkInTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${'In'.tr(context)}: ${record.checkInTime}',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
              if (record.checkOutTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${'Out'.tr(context)}: ${record.checkOutTime}',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          Text(
            record.date,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
