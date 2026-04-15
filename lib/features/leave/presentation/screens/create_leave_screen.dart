import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../holidays/presentation/providers/holiday_providers.dart';
import '../providers/leave_providers.dart';
import 'leave_calendar_picker.dart';

const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'zip'];
const _maxFileSizeMb = 10;

class CreateLeaveScreen extends ConsumerStatefulWidget {
  const CreateLeaveScreen({super.key});

  @override
  ConsumerState<CreateLeaveScreen> createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends ConsumerState<CreateLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTimeRange? _dateRange;

  static final _apiDateFormat = DateFormat('yyyy-MM-dd', 'en');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaveBalancesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(createLeaveFormProvider);
    final notifier = ref.read(createLeaveFormProvider.notifier);
    final balancesState = ref.watch(leaveBalancesProvider);

    ref.listen<CreateLeaveFormState>(createLeaveFormProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                (next.successMessage ?? 'Leave request sent successfully')
                    .tr(context)),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child: balancesState.isLoading
                ? const Center(child: LoadingIndicator())
                : balancesState.error != null
                    ? ErrorFullScreen(
                        error: balancesState.error!,
                        onRetry: () =>
                            ref.read(leaveBalancesProvider.notifier).load(),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Leave Type Dropdown ──
                              _buildLeaveTypeDropdown(
                                  context, form, notifier, balancesState),
                              const SizedBox(height: 18),

                              // ── Date Range ──
                              _buildDateRangeField(context, form, notifier),

                              // ── Days count helper ──
                              if (_dateRange != null)
                                _buildDaysCount(context),

                              const SizedBox(height: 18),

                              // ── Reason (optional) ──
                              Text(
                                'Reason'.tr(context),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                maxLines: 3,
                                onChanged: (v) => notifier.setReason(v),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Enter reason (optional)'.tr(context),
                                  hintStyle: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: context.appColors.textMuted,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Attachment ──
                              _buildAttachmentField(context, form, notifier),
                            ],
                          ),
                        ),
                      ),
          ),

          // ── Two buttons: Save Draft & Submit ──
          if (!balancesState.isLoading && balancesState.error == null)
            StickyBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: form.isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate() &&
                                  _validateAttachment(form)) {
                                notifier.submit(action: 'draft');
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primaryMid),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Save as draft'.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryMid,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Submit request'.tr(context),
                      loading: form.isLoading,
                      onTap: form.isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate() &&
                                  _validateAttachment(form)) {
                                notifier.submit(action: 'submit');
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Leave Type Dropdown
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLeaveTypeDropdown(
    BuildContext context,
    CreateLeaveFormState form,
    CreateLeaveFormController notifier,
    LeaveBalancesState balancesState,
  ) {
    final balances = balancesState.balances;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave type'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: form.leaveTypeId,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            errorText: form.fieldError('leave_type_id')?.tr(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          hint: Text(
            'Select leave type'.tr(context),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: context.appColors.textMuted,
            ),
          ),
          validator: (value) {
            if (value == null) return 'This field is required'.tr(context);
            return null;
          },
          items: balances.map((b) {
            final typeName = b.leaveType?.name ?? '';
            final availableNum = b.available % 1 == 0
                ? b.available.toInt().toString()
                : b.available.toStringAsFixed(1);
            final totalNum = b.totalEntitlement % 1 == 0
                ? b.totalEntitlement.toInt().toString()
                : b.totalEntitlement.toStringAsFixed(1);

            return DropdownMenuItem<int>(
              value: b.leaveType?.id,
              child: Text(
                '$typeName ($availableNum ${'available of'.tr(context)} $totalNum ${'day'.tr(context)})',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) notifier.setLeaveType(value);
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Date Range Field
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDateRangeField(
    BuildContext context,
    CreateLeaveFormState form,
    CreateLeaveFormController notifier,
  ) {
    final hasRange = _dateRange != null;
    final startError = form.fieldError('start_date')?.tr(context);
    final endError = form.fieldError('end_date')?.tr(context);
    final errorText = startError ?? endError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave period'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickDateRange(notifier),
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: hasRange
                      ? Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From'.tr(context),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: context.appColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    AppFuns.formatDate(_dateRange!.start),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.appColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward,
                                  size: 16, color: context.appColors.textMuted),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To'.tr(context),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: context.appColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    AppFuns.formatDate(_dateRange!.end),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.appColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Select leave period'.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: context.appColors.textMuted,
                          ),
                        ),
                ),
                Icon(Icons.date_range_rounded,
                    size: 20, color: AppColors.primaryMid),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Calculate leave days excluding weekly days off and holidays.
  int _calcLeaveDays() {
    if (_dateRange == null) return 0;

    // Weekly days off from work schedule.
    const weekdayKeys = {1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat', 7: 'sun'};
    final workDays = ref.read(authProvider).employee?.contract?.workSchedule?.workDays;
    final disabledWeekdays = <int>{};
    if (workDays != null) {
      for (final e in weekdayKeys.entries) {
        if (workDays[e.value] == false) disabledWeekdays.add(e.key);
      }
    }

    // Holiday dates.
    final holidays = ref.read(holidaysProvider).holidays;
    final holidayDates = <DateTime>{};
    for (final h in holidays) {
      final start = DateTime.tryParse(h.startDate);
      final end = DateTime.tryParse(h.endDate);
      if (start == null) continue;
      final endDate = end ?? start;
      for (var d = start; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
        holidayDates.add(DateTime(d.year, d.month, d.day));
      }
    }

    int count = 0;
    var d = _dateRange!.start;
    while (!d.isAfter(_dateRange!.end)) {
      final norm = DateTime(d.year, d.month, d.day);
      if (!disabledWeekdays.contains(d.weekday) && !holidayDates.contains(norm)) {
        count++;
      }
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  Widget _buildDaysCount(BuildContext context) {
    final days = _calcLeaveDays();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.primaryMid),
          const SizedBox(width: 6),
          Text(
            '${'Leave days'.tr(context)}: $days',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryMid,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(CreateLeaveFormController notifier) async {
    final picked = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        builder: (_) => LeaveCalendarPicker(initialRange: _dateRange),
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      notifier.setDateRange(
        _apiDateFormat.format(picked.start),
        _apiDateFormat.format(picked.end),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Attachment Field
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAttachmentField(
    BuildContext context,
    CreateLeaveFormState form,
    CreateLeaveFormController notifier,
  ) {
    final selected = ref.watch(selectedBalanceProvider);
    final isRequired = selected?.leaveType?.requiresAttachment == true;
    final hasFile = form.attachmentPath != null;
    final fileName = form.attachmentName ?? '';
    final apiError = form.fieldError('attachment')?.tr(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with optional red asterisk
        Row(
          children: [
            Text(
              'Attachment'.tr(context),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isRequired
                    ? AppColors.error
                    : context.appColors.textSecondary,
              ),
            ),
            if (isRequired)
              Text(' *',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ))
            else
              Text(' (${'optional'.tr(context)})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  )),
          ],
        ),
        const SizedBox(height: 6),

        // File picker button
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickFile(notifier),
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              errorText: apiError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 20, color: AppColors.primaryMid),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasFile ? fileName : 'Tap to choose a file'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: hasFile
                          ? context.appColors.textPrimary
                          : context.appColors.textMuted,
                      fontWeight:
                          hasFile ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasFile)
                  GestureDetector(
                    onTap: () => notifier.clearAttachment(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Required warning
        if (isRequired) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'This leave type requires an attachment'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Static help text
        const SizedBox(height: 6),
        Text(
          'Allowed: PDF, JPG, JPEG, PNG, ZIP — max 10 MB'.tr(context),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(CreateLeaveFormController notifier) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final path = picked.path;
      if (path == null) return;

      // Validate size
      final sizeMb = File(path).lengthSync() / (1024 * 1024);
      if (sizeMb > _maxFileSizeMb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File exceeds 10 MB'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      notifier.setAttachment(path, picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file'.tr(context),
                style: const TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  bool _validateAttachment(CreateLeaveFormState form) {
    final selected = ref.read(selectedBalanceProvider);
    final isRequired = selected?.leaveType?.requiresAttachment == true;
    if (isRequired && form.attachmentPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This leave type requires an attachment'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    return true;
  }
}
