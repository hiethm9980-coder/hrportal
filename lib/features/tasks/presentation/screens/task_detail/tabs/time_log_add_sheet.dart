import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/errors/exceptions.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/utils/app_funs.dart';
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
  final _scrollCtl = ScrollController();
  final _hoursController = TextEditingController();
  final _descController = TextEditingController();

  // FormField-level keys so we can query `hasError` directly after
  // `validate()` runs, and let `_scrollToFirstError` reach the right field.
  final _hoursFieldKey = GlobalKey<FormFieldState<String>>();
  final _descFieldKey = GlobalKey<FormFieldState<String>>();

  // Section keys — one per field, in visual top-to-bottom order.
  // `_scrollToFirstError` iterates these in order and ensure-visibles the
  // first one that has an error (client or server).
  final _fieldKeys = <String, GlobalKey>{
    'date_from': GlobalKey(debugLabel: 'tl_date_range'),
    'hours_spent': GlobalKey(debugLabel: 'tl_hours'),
    'description': GlobalKey(debugLabel: 'tl_description'),
  };

  /// Server-side field errors keyed by backend field name. Validators check
  /// this first; setting a key here + calling `validate()` surfaces the
  /// inline error automatically.
  final _serverErrors = <String, String>{};

  /// Client-side error for the date-range row (non-`TextFormField`): stores
  /// the reason message to display. Cleared when the user corrects the
  /// selection (taps a valid date).
  String? _dateRangeError;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  DateTime _focusedDay = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _scrollCtl.dispose();
    _hoursController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Drives the From→To range selection manually so we can support the
  /// "tap the same day twice → single-day range" UX, which the package's
  /// built-in [RangeSelectionMode] doesn't model directly.
  ///
  /// State machine (per tap):
  ///   - nothing selected   → set [_dateFrom] = tapped, [_dateTo] = null
  ///   - only [_dateFrom] set:
  ///       - same day       → [_dateTo] = [_dateFrom] (single-day range)
  ///       - later day      → [_dateTo] = tapped
  ///       - earlier day    → swap ([_dateFrom] = tapped, [_dateTo] = old start)
  ///   - both set           → start fresh ([_dateFrom] = tapped, [_dateTo] = null)
  void _onDayTapped(DateTime selected, DateTime focused) {
    final sel = DateTime(selected.year, selected.month, selected.day);
    setState(() {
      _focusedDay = focused;
      if (_dateFrom == null || _dateTo != null) {
        _dateFrom = sel;
        _dateTo = null;
      } else {
        final start = _dateFrom!;
        if (sel.isBefore(start)) {
          _dateFrom = sel;
          _dateTo = start;
        } else {
          // sel == start → single day (user's explicit "tap twice" flow).
          // sel  > start → normal range end.
          _dateTo = sel;
        }
      }
      // User is actively picking — any previous "required / tap again"
      // error shown for the date range should vanish.
      if (_dateRangeError != null) _dateRangeError = null;
      if (_serverErrors.containsKey('date_from')) {
        _serverErrors.remove('date_from');
      }
      if (_serverErrors.containsKey('date_to')) {
        _serverErrors.remove('date_to');
      }
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    // Wipe any prior server errors — the user is retrying.
    if (_serverErrors.isNotEmpty) {
      setState(() => _serverErrors.clear());
    }

    // ── 1. Client-side validation ──────────────────────────────────
    // Date range: start required, end required (a second tap, which for a
    // single day equals start — handled by _onDayTapped).
    String? dateErr;
    if (_dateFrom == null) {
      dateErr = 'This field is required'.tr(context);
    } else if (_dateTo == null) {
      dateErr = 'Tap again to set the end date'.tr(context);
    }
    if (_dateRangeError != dateErr) {
      setState(() => _dateRangeError = dateErr);
    }

    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || dateErr != null) {
      await _scrollToFirstError();
      if (!mounted) return;
      _showValidationSnack(
          'Please correct the highlighted fields'.tr(context));
      return;
    }

    // ── 2. Send ───────────────────────────────────────────────────
    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final dateFromStr = _fmt(_dateFrom!);
    final dateToStr = _fmt(_dateTo!);

    setState(() => _isSaving = true);
    try {
      await ref.read(timeLogsProvider(widget.taskId).notifier).createLog(
            dateFrom: dateFromStr,
            dateTo: dateToStr,
            hoursSpent: hours,
            description: _descController.text,
          );
      // Close immediately — parent sets `_showAddSheet = false` and may
      // dispose this widget in the same frame; do not gate on post-frame.
      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.onCreated();
    } on ValidationException catch (e) {
      // ── 3. Server-side field errors ──────────────────────────────
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _serverErrors.clear();
        e.fieldErrors.forEach((field, errs) {
          if (errs.isNotEmpty) _serverErrors[field] = errs.first;
        });
        // Surface server-side date errors on the single date-range row.
        final dateServerErr =
            _serverErrors['date_from'] ?? _serverErrors['date_to'];
        if (dateServerErr != null) _dateRangeError = dateServerErr;
      });
      _formKey.currentState?.validate();
      await _scrollToFirstError();
      if (!mounted) return;
      _showValidationSnack(
        e.message.isNotEmpty
            ? e.message
            : 'Please correct the highlighted fields'.tr(context),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      GlobalErrorHandler.show(context, GlobalErrorHandler.handle(e));
    }
  }

  // ── Form-scaffold helpers ────────────────────────────────────────

  /// Floating red snack bar for form-level validation summaries.
  void _showValidationSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _fieldHasError(String name) {
    if (_serverErrors.containsKey(name)) return true;
    switch (name) {
      case 'date_from':
        return _dateRangeError != null;
      case 'hours_spent':
        return _hoursFieldKey.currentState?.hasError ?? false;
      case 'description':
        return _descFieldKey.currentState?.hasError ?? false;
      default:
        return false;
    }
  }

  Future<void> _scrollToFirstError() async {
    for (final entry in _fieldKeys.entries) {
      if (!_fieldHasError(entry.key)) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
  }

  /// Drop a server error from a field as soon as the user edits it — they
  /// are actively fixing the issue, don't nag them further.
  void _clearServerErrorFor(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors.remove(field));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Full-tab-height "page" layout: gradient header + scrollable form +
    // sticky footer with Cancel/Save. Material wraps everything so text
    // fields get proper ripples / selection handles.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Container(
            color: colors.bg,
            child: Column(
              children: [
                // ── Gradient header ──────────────────────────────────────
                Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.navyGradient),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    bottom: 14,
                    left: 14,
                    right: 14,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _isSaving ? null : widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New time log'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Form body ───────────────────────────────────────────
                // Uses the project's standard form scaffold convention
                // (see `memory/reference_form_scaffold.md`): a Form wrapping
                // a SingleChildScrollView + Column, with per-section
                // KeyedSubtrees so `_scrollToFirstError` can ensure-visible
                // the offending field on validation failure.
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      controller: _scrollCtl,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // ── Range calendar: Date from → Date to ────────
                      // Tap 1: picks start; Tap 2 (same day): single-day;
                      // Tap 2 (later day): full range; Tap 3: reset.
                      KeyedSubtree(
                        key: _fieldKeys['date_from'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RangeSummary(
                              dateFrom: _dateFrom,
                              dateTo: _dateTo,
                            ),
                            const SizedBox(height: 8),
                            _RangeCalendar(
                              focusedDay: _focusedDay,
                              rangeStart: _dateFrom,
                              rangeEnd: _dateTo,
                              onDayTapped: _onDayTapped,
                              onPageChanged: (f) => _focusedDay = f,
                            ),
                            if (_dateRangeError != null)
                              _TlInlineError(message: _dateRangeError!),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Hours spent — decimal 0.25..24.
                      KeyedSubtree(
                        key: _fieldKeys['hours_spent'],
                        child: TextFormField(
                          key: _hoursFieldKey,
                          controller: _hoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
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
                          onChanged: (_) =>
                              _clearServerErrorFor('hours_spent'),
                          validator: (value) {
                            // Server-provided field errors win — they
                            // carry localized Arabic messages that
                            // already match the backend's business rules.
                            final server = _serverErrors['hours_spent'];
                            if (server != null) return server;

                            final v = (value ?? '').trim();
                            if (v.isEmpty) {
                              return 'This field is required'.tr(context);
                            }
                            final parsed = double.tryParse(v);
                            if (parsed == null) {
                              return 'Enter a valid positive number'
                                  .tr(context);
                            }
                            if (parsed < 0.25 || parsed > 24) {
                              return 'Hours must be between 0.25 and 24'
                                  .tr(context);
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Description — optional, up to 255 chars (server
                      // enforces the cap as well).
                      KeyedSubtree(
                        key: _fieldKeys['description'],
                        child: TextFormField(
                          key: _descFieldKey,
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
                          onChanged: (_) =>
                              _clearServerErrorFor('description'),
                          validator: (value) {
                            final server = _serverErrors['description'];
                            if (server != null) return server;
                            // Optional field — only the server-side
                            // length cap matters. 255 is enforced by
                            // `maxLength`, but a paste could slip past
                            // it; be defensive.
                            final v = (value ?? '').trim();
                            if (v.length > 255) {
                              return 'Description must not exceed 255 characters'
                                  .tr(context);
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Action row — upgraded for visibility:
                      //   - Taller hit targets (52 px) match the Save Task
                      //     button on the Add Task screen.
                      //   - Cancel gains a filled surface + thicker gray300
                      //     border + close icon so it reads as an actual
                      //     button, not a faded text link.
                      //   - Save gains an icon + shadow for emphasis.
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: colors.bgCard,
                                  foregroundColor: colors.textPrimary,
                                  side: BorderSide(
                                      color: colors.gray300, width: 1.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSaving ? null : widget.onClose,
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: colors.textSecondary,
                                ),
                                label: Text(
                                  'Cancel'.tr(context),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryMid,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _isSaving ? null : _submit,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_rounded,
                                        size: 20),
                                label: Text(
                                  _isSaving
                                      ? 'Saving...'.tr(context)
                                      : 'Log time'.tr(context),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      // Match the Add-Task screen: elevated surface colour so fields read
      // as a distinct input against the page background. `bgCard` resolves
      // to white in the light theme and a muted near-black in dark mode.
      fillColor: colors.bgCard,
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

/// Matches the error text rendered by `TextFormField` under invalid input,
/// but for non-`TextFormField` sections (here: the date-range row).
/// Prefixed `_Tl…` so it doesn't collide with the identically-named helper
/// in `add_task_screen.dart` if both ever live in the same scope.
class _TlInlineError extends StatelessWidget {
  final String message;
  const _TlInlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: AppColors.error,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a compact "From → To" summary above the calendar so the user sees
/// at a glance what they've selected. When a single day is picked (tap-tap
/// on the same day) both halves display the same date.
class _RangeSummary extends StatelessWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _RangeSummary({required this.dateFrom, required this.dateTo});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Same elevated surface as every other input field in the form
        // (Hours, Description, calendar card) so the row reads as an
        // actual "Date from → Date to" field and not as page background.
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummarySlot(
              label: 'Date from'.tr(context),
              value: dateFrom,
              placeholder: 'Tap a day below'.tr(context),
              required: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ),
          Expanded(
            child: _SummarySlot(
              label: 'Date to'.tr(context),
              value: dateTo,
              placeholder: 'Tap again to confirm'.tr(context),
              required: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySlot extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String placeholder;
  final bool required;

  const _SummarySlot({
    required this.label,
    required this.value,
    required this.placeholder,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 3),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value != null
              ? '${value!.year.toString().padLeft(4, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
              : placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: value != null ? colors.textPrimary : colors.textDisabled,
          ),
        ),
      ],
    );
  }
}

/// TableCalendar used purely for *display* of the currently-selected range.
/// We don't lean on the package's built-in [RangeSelectionMode] because it
/// doesn't support the "tap the same day twice → single-day range" UX
/// cleanly — instead we drive everything via [onDaySelected] and pass the
/// chosen range back out through [onDayTapped].
class _RangeCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final void Function(DateTime selected, DateTime focused) onDayTapped;
  final ValueChanged<DateTime> onPageChanged;

  const _RangeCalendar({
    required this.focusedDay,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onDayTapped,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TableCalendar<void>(
        firstDay: DateTime(now.year - 5),
        lastDay: DateTime(now.year + 5),
        focusedDay: focusedDay,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: ''},
        // Let vertical drags bubble up to the outer scrollable list so the
        // page scrolls normally. We only want horizontal swipes here (month
        // navigation).
        availableGestures: AvailableGestures.horizontalSwipe,
        startingDayOfWeek: StartingDayOfWeek.saturday,
        // `RangeSelectionMode.toggledOn` + explicit `rangeStartDay`/`rangeEndDay`
        // make the package paint the highlight band — we still catch taps
        // via `onDaySelected` (which fires in this mode) so we can drive the
        // state machine ourselves, including the same-day-twice case.
        rangeSelectionMode: RangeSelectionMode.toggledOn,
        rangeStartDay: rangeStart,
        rangeEndDay: rangeEnd,
        onDaySelected: onDayTapped,
        onPageChanged: onPageChanged,
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ),
        // Western digits in the month/year title (see AppFuns.formatMonthYear).
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, day) {
            return Center(
              child: Text(
                AppFuns.formatMonthYear(day),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            );
          },
        ),
        calendarStyle: CalendarStyle(
          rangeStartDecoration: const BoxDecoration(
            color: AppColors.primaryMid,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: const BoxDecoration(
            color: AppColors.primaryMid,
            shape: BoxShape.circle,
          ),
          withinRangeDecoration: BoxDecoration(
            color: AppColors.primaryMid.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          rangeHighlightColor: AppColors.primaryMid.withValues(alpha: 0.12),
          rangeStartTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          rangeEndTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          withinRangeTextStyle: TextStyle(
            fontFamily: 'Cairo',
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryMid.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: AppColors.primaryMid,
          ),
          defaultTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textPrimary),
          weekendTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textSecondary),
          outsideTextStyle:
              TextStyle(fontFamily: 'Cairo', color: colors.textDisabled),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
          ),
          weekendStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }
}
