import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/controllers/global_error_handler.dart';
import '../../../providers/time_logs_provider.dart';

/// "New time log" sheet — rendered as an in-tree overlay (NOT via
/// `showModalBottomSheet`) so it sits inside the task-detail Scaffold's body
/// and the bottom navigation bar of the shell stays visible above it.
///
/// The parent owns the visibility state and drives show/hide through the
/// [onClose] and [onCreated] callbacks. The sheet itself has no knowledge of
/// the surrounding Navigator.
class TimeLogAddSheet extends ConsumerStatefulWidget {
  final int taskId;

  /// Called when the user taps Cancel or otherwise dismisses the sheet
  /// without creating a log.
  final VoidCallback onClose;

  /// Called after a log is successfully created on the server. The parent is
  /// responsible for hiding the sheet and showing any success toast.
  final VoidCallback onCreated;

  const TimeLogAddSheet({
    super.key,
    required this.taskId,
    required this.onClose,
    required this.onCreated,
  });

  @override
  ConsumerState<TimeLogAddSheet> createState() => _TimeLogAddSheetState();
}

class _TimeLogAddSheetState extends ConsumerState<TimeLogAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _descController = TextEditingController();

  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isSaving = false;
  // True after the first submit attempt — drives the "required" hint under
  // the date field so it only appears AFTER the user actually tries to save.
  bool _submitted = false;

  @override
  void dispose() {
    _hoursController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? _dateFrom ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        // If the user picked a `from` later than the existing `to`, clear
        // `to` so we never send an invalid range to the server.
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = null;
      } else {
        _dateTo = picked;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_dateFrom == null) return;

    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final dateFromStr = _fmt(_dateFrom!);
    final dateToStr = _dateTo != null ? _fmt(_dateTo!) : null;

    setState(() => _isSaving = true);
    try {
      await ref.read(timeLogsProvider(widget.taskId).notifier).createLog(
            dateFrom: dateFromStr,
            dateTo: dateToStr,
            hoursSpent: hours,
            description: _descController.text,
          );
      if (!mounted) return;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // `Material` is required so the text fields get correct ripple / text
    // selection handles. We use type=transparency so the custom rounded
    // container below is what the user actually sees.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.gray200,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'New time log'.tr(context),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Date from + date to side by side.
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: '${'Date from'.tr(context)} *',
                        value: _dateFrom,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateField(
                        label:
                            '${'Date to'.tr(context)} (${'optional'.tr(context)})',
                        value: _dateTo,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                if (_submitted && _dateFrom == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'This field is required'.tr(context),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Hours spent — decimal 0.25..24.
                TextFormField(
                  controller: _hoursController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: _fieldDecoration(
                    context,
                    label: '${'Hours spent'.tr(context)} *',
                    hint: '2.5',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'This field is required'.tr(context);
                    final parsed = double.tryParse(v);
                    if (parsed == null) {
                      return 'Enter a valid positive number'.tr(context);
                    }
                    if (parsed < 0.25 || parsed > 24) {
                      return 'Hours must be between 0.25 and 24'.tr(context);
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Description — optional, up to 255 chars (server enforces).
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 255,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: _fieldDecoration(
                    context,
                    label:
                        '${'Description'.tr(context)} (${'optional'.tr(context)})',
                    hint: 'Describe the work...'.tr(context),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: colors.gray200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : widget.onClose,
                        child: Text(
                          'Cancel'.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Log time'.tr(context),
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final colors = context.appColors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        color: colors.textSecondary,
      ),
      hintStyle: TextStyle(fontFamily: 'Cairo', color: colors.textDisabled),
      filled: true,
      fillColor: colors.bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryMid, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
    );
  }

  /// Formats a DateTime as `yyyy-MM-dd` (what the backend expects).
  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.gray200),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: colors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? '${value!.year.toString().padLeft(4, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                        : 'Select date'.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: value != null
                          ? colors.textPrimary
                          : colors.textDisabled,
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
