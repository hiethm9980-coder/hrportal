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
import '../../data/models/leave_models.dart';
import '../providers/leave_providers.dart';

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
                              if (_formKey.currentState!.validate()) {
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
                              if (_formKey.currentState!.validate()) {
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
          value: form.leaveTypeId,
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

  Future<void> _pickDateRange(CreateLeaveFormController notifier) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      locale: Localizations.localeOf(context),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryMid,
              onPrimary: Colors.white,
              surface: context.appColors.bgCard,
              onSurface: context.appColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      notifier.setDateRange(
        _apiDateFormat.format(picked.start),
        _apiDateFormat.format(picked.end),
      );
    }
  }
}
