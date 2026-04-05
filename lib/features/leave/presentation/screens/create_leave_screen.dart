import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/features/leave/data/models/leave_models.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';
import 'package:intl/intl.dart';

import '../../../../shared/controllers/global_error_handler.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../providers/leave_providers.dart';

class CreateLeaveScreen extends ConsumerWidget {
  const CreateLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(leavesListProvider);
    final form = ref.watch(createLeaveFormProvider);
    final notifier = ref.read(createLeaveFormProvider.notifier);

    ref.listen<CreateLeaveFormState>(createLeaveFormProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request sent successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
      if (next.error != null && prev?.error != next.error) {
        GlobalErrorHandler.show(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Request leave'.tr(context),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: listState.isLoading
                ? const Center(child: LoadingIndicator())
                : listState.error != null
                    ? ErrorFullScreen(
                        error: listState.error!,
                        onRetry: () =>
                            ref.read(leavesListProvider.notifier).refresh(),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Leave type'.tr(context),
                                style: TextStyle(fontFamily: 'Cairo',fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.appColors.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: form.leaveTypeId,
                              isExpanded: true,
                              itemHeight: null,
                              items: listState.leaveTypes.map((t) {
                                LeaveBalance? bal;
                                try {
                                  bal = listState.balances.firstWhere(
                                      (b) => (b.leaveType?.id ?? 0) == (t.id ?? 0));
                                } catch (_) { bal = null; }
                                final nf = NumberFormat('0.0');
                                final availableDays = bal?.available ?? 0.0;
                                final meta = t.isPaid
                                    ? '${'Available'.tr(context)}: ${nf.format(availableDays)} ${'day'.tr(context)}'
                                    : 'Unpaid — no balance'.tr(context);
                                return DropdownMenuItem<int>(
                                  value: t.id ?? 0,
                                  child: Text('${t.name} ($meta)',
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (v) { if (v != null) notifier.setLeaveType(v); },
                              decoration: InputDecoration(errorText: form.fieldError('leave_type_id')?.tr(context)),
                            ),
                            const SizedBox(height: 14),
                            _DateField(
                              label: 'Start date'.tr(context),
                              value: form.startDate,
                              errorText: form.fieldError('start_date')?.tr(context),
                              onPick: (date) => notifier.setStartDate(date),
                            ),
                            const SizedBox(height: 14),
                            _DateField(
                              label: 'End date'.tr(context),
                              value: form.endDate,
                              errorText: form.fieldError('end_date')?.tr(context),
                              onPick: (date) => notifier.setEndDate(date),
                            ),
                            const SizedBox(height: 14),
                            Text('Duration'.tr(context),
                                style: TextStyle(fontFamily: 'Cairo',fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.appColors.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: form.dayPart,
                              items: [
                                DropdownMenuItem(value: 'full',
                                    child: Text('Full day'.tr(context),
                                        style: TextStyle(fontFamily: 'Cairo',fontSize: 13))),
                              ],
                              onChanged: (v) { if (v != null) notifier.setDayPart(v); },
                              decoration: InputDecoration(errorText: form.fieldError('day_part')?.tr(context)),
                            ),
                            const SizedBox(height: 14),
                            Text('Reason (optional)'.tr(context),
                                style: TextStyle(fontFamily: 'Cairo',fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.appColors.textSecondary)),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: form.reason,
                              maxLines: 3,
                              onChanged: notifier.setReason,
                              style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                              decoration: InputDecoration(errorText: form.fieldError('reason')?.tr(context)),
                            ),
                          ],
                        ),
                      ),
          ),
          StickyBottomBar(
            child: PrimaryButton(
              text: 'Submit request'.tr(context),
              loading: form.isLoading,
              onTap: form.isLoading ? null : () => notifier.submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final String? errorText;
  final ValueChanged<String> onPick;

  const _DateField({required this.label, required this.value, required this.onPick, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Cairo',fontSize: 12,
            fontWeight: FontWeight.w600, color: context.appColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2),
            );
            if (picked != null) {
              onPick('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(errorText: errorText),
            child: Row(
              children: [
                Expanded(child: Text(
                    value.isEmpty ? 'Select date'.tr(context) : value,
                    style: TextStyle(fontFamily: 'Cairo',fontSize: 13))),
                const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryMid),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
