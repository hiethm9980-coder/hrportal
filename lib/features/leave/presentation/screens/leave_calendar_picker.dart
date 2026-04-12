import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../holidays/data/models/holiday_models.dart';
import '../../../holidays/presentation/providers/holiday_providers.dart';
import '../../data/models/booked_day_models.dart';
import '../providers/booked_days_provider.dart';

/// Full-screen calendar picker for selecting a leave date range.
///
/// - Weekly days off (from employee work schedule) are disabled.
/// - Official holidays are disabled and labeled.
/// - Approved leaves shown in light green (disabled).
/// - Pending leaves shown in light yellow (disabled).
/// - Tap month/year title to switch to month-grid picker.
class LeaveCalendarPicker extends ConsumerStatefulWidget {
  final DateTimeRange? initialRange;

  const LeaveCalendarPicker({super.key, this.initialRange});

  @override
  ConsumerState<LeaveCalendarPicker> createState() =>
      _LeaveCalendarPickerState();
}

class _LeaveCalendarPickerState extends ConsumerState<LeaveCalendarPicker> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  /// true = show month grid, false = show calendar.
  bool _showMonthPicker = false;

  /// Year displayed in the month picker grid.
  late int _pickerYear;

  // ── Bounds: ±360 days from today ──
  static final DateTime _minDate =
      DateTime.now().subtract(const Duration(days: 360));
  static final DateTime _maxDate =
      DateTime.now().add(const Duration(days: 360));

  /// First allowed month (year, month).
  static final int _minYear = _minDate.year;
  static final int _minMonth = _minDate.month;

  /// Last allowed month (year, month).
  static final int _maxYear = _maxDate.year;
  static final int _maxMonth = _maxDate.month;

  /// Check if a given month/year is within the allowed range.
  bool _isMonthInRange(int year, int month) {
    if (year < _minYear || year > _maxYear) return false;
    if (year == _minYear && month < _minMonth) return false;
    if (year == _maxYear && month > _maxMonth) return false;
    return true;
  }

  // Day name mapping: DateTime.weekday (1=Mon..7=Sun) → backend key.
  static const _weekdayKeys = {
    1: 'mon',
    2: 'tue',
    3: 'wed',
    4: 'thu',
    5: 'fri',
    6: 'sat',
    7: 'sun',
  };

  static const _arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRange != null) {
      _rangeStart = widget.initialRange!.start;
      _rangeEnd = widget.initialRange!.end;
      _focusedDay = widget.initialRange!.start;
    }
    _pickerYear = _focusedDay.year;
    // Load holidays + booked days.
    Future.microtask(() {
      ref.read(holidaysProvider.notifier).load();
      _loadBookedDays(_focusedDay);
    });
  }

  /// Format month as YYYYMM for the API.
  String _monthKey(DateTime day) {
    return '${day.year}${day.month.toString().padLeft(2, '0')}';
  }

  /// Load booked days for the focused month.
  void _loadBookedDays(DateTime day) {
    ref.read(bookedDaysProvider.notifier).loadMonth(_monthKey(day));
  }

  /// Get the set of disabled weekday numbers from work_days.
  Set<int> get _disabledWeekdays {
    final workDays =
        ref.read(authProvider).employee?.contract?.workSchedule?.workDays;
    if (workDays == null || workDays.isEmpty) return {};

    final disabled = <int>{};
    for (final entry in _weekdayKeys.entries) {
      final dayKey = entry.value;
      if (workDays[dayKey] == false) {
        disabled.add(entry.key);
      }
    }
    return disabled;
  }

  /// Build a set of all holiday dates for fast lookup.
  Set<DateTime> _holidayDates(List<Holiday> holidays) {
    final dates = <DateTime>{};
    for (final h in holidays) {
      final start = DateTime.tryParse(h.startDate);
      final end = DateTime.tryParse(h.endDate);
      if (start == null) continue;
      final endDate = end ?? start;
      for (var d = start;
          !d.isAfter(endDate);
          d = d.add(const Duration(days: 1))) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }
    return dates;
  }

  /// Find holiday name for a specific date.
  String? _holidayName(DateTime day, List<Holiday> holidays) {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final h in holidays) {
      final start = DateTime.tryParse(h.startDate);
      final end = DateTime.tryParse(h.endDate);
      if (start == null) continue;
      final endDate = end ?? start;
      final normStart = DateTime(start.year, start.month, start.day);
      final normEnd = DateTime(endDate.year, endDate.month, endDate.day);
      if (!normalized.isBefore(normStart) && !normalized.isAfter(normEnd)) {
        return h.name;
      }
    }
    return null;
  }

  bool _isDayDisabled(
    DateTime day,
    Set<int> disabledWeekdays,
    Set<DateTime> holidayDates,
    Set<String> bookedDates,
  ) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (disabledWeekdays.contains(day.weekday)) return true;
    if (holidayDates.contains(normalized)) return true;
    final dateStr = DateFormat('yyyy-MM-dd', 'en').format(normalized);
    if (bookedDates.contains(dateStr)) return true;
    return false;
  }

  /// Check if any booked day exists between [start] and [end].
  bool _hasOverlap(DateTime start, DateTime end, Set<String> bookedDates) {
    final fmt = DateFormat('yyyy-MM-dd', 'en');
    var d = start;
    while (!d.isAfter(end)) {
      if (bookedDates.contains(fmt.format(d))) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  void _onDaySelected(
    DateTime day,
    Set<int> disabledWeekdays,
    Set<DateTime> holidayDates,
    Set<String> bookedDates,
  ) {
    if (_isDayDisabled(day, disabledWeekdays, holidayDates, bookedDates)) return;

    if (_rangeStart == null || _rangeEnd != null) {
      setState(() {
        _rangeStart = day;
        _rangeEnd = null;
      });
    } else {
      DateTime start = _rangeStart!;
      DateTime end = day;
      if (day.isBefore(start)) {
        end = start;
        start = day;
      }

      // Check for overlap with booked days between start and end.
      if (_hasOverlap(start, end, bookedDates)) {
        // Cancel selection and show error.
        setState(() {
          _rangeStart = null;
          _rangeEnd = null;
        });
        final isAr =
            Localizations.localeOf(context).languageCode == 'ar';
        final msg = isAr
            ? 'لا يمكن تحديد هذه الفترة، يوجد طلب إجازة سابق (معتمد أو معلق) يتداخل مع التواريخ المحددة.\nيرجى اختيار فترة أخرى.'
            : 'Cannot select this period. There is an existing leave request (approved or pending) that overlaps with the selected dates.\nPlease choose a different period.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            duration: const Duration(days: 365),
          ),
        );
        return;
      }

      setState(() {
        _rangeStart = start;
        _rangeEnd = end;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pop(DateTimeRange(start: start, end: end));
        }
      });
    }
  }

  void _confirm() {
    if (_rangeStart != null && _rangeEnd != null) {
      Navigator.of(context)
          .pop(DateTimeRange(start: _rangeStart!, end: _rangeEnd!));
    } else if (_rangeStart != null) {
      Navigator.of(context)
          .pop(DateTimeRange(start: _rangeStart!, end: _rangeStart!));
    }
  }

  /// Called when user picks a month from the grid.
  void _onMonthSelected(int month) {
    final newFocused = DateTime(_pickerYear, month, 1);
    setState(() {
      _focusedDay = newFocused;
      _showMonthPicker = false;
    });
    // Load data for the selected month.
    _loadBookedDays(newFocused);
    final holidaysState = ref.read(holidaysProvider);
    if (_pickerYear != holidaysState.year) {
      ref.read(holidaysProvider.notifier).load(year: _pickerYear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidaysState = ref.watch(holidaysProvider);
    final bookedState = ref.watch(bookedDaysProvider);
    final holidays = holidaysState.holidays;
    final disabledWeekdays = _disabledWeekdays;
    final holidayDates = _holidayDates(holidays);
    final bookedDates = bookedState.bookedDates;
    final bookedDaysByDate = bookedState.daysByDate;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dateFormat = DateFormat('yyyy-MM-dd', 'en');

    return Scaffold(
      appBar: AppBar(
        title: Text('Select leave period'.tr(context),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_rangeStart != null)
            TextButton(
              onPressed: _confirm,
              child: Text(
                'Confirm'.tr(context),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryMid,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Selected range summary (always visible) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.primaryMid.withValues(alpha: 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_rangeStart != null) ...[
                  Text(
                    dateFormat.format(_rangeStart!),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryMid,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward,
                        size: 16, color: AppColors.primaryMid),
                  ),
                  if (_rangeEnd != null)
                    Text(
                      dateFormat.format(_rangeEnd!),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMid,
                      ),
                    )
                  else
                    Text(
                      'End date'.tr(context),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: context.appColors.textMuted,
                      ),
                    ),
                ] else ...[
                  Text(
                    'Start date'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: context.appColors.textMuted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward,
                        size: 16, color: context.appColors.textMuted),
                  ),
                  Text(
                    'End date'.tr(context),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Main content: Month Picker OR Calendar ──
          Expanded(
            child: _showMonthPicker
                ? _buildMonthPickerView(isAr)
                : _buildCalendarView(
                    isAr: isAr,
                    holidays: holidays,
                    holidaysState: holidaysState,
                    disabledWeekdays: disabledWeekdays,
                    holidayDates: holidayDates,
                    bookedDates: bookedDates,
                    bookedDaysByDate: bookedDaysByDate,
                    bookedState: bookedState,
                    dateFormat: dateFormat,
                  ),
          ),

          // ── Legend ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendDot(
                    color: Colors.grey.shade300,
                    label: 'Day off'.tr(context)),
                _LegendDot(
                    color: Colors.red.shade300,
                    label: 'Holiday'.tr(context)),
                _LegendDot(
                    color: Colors.green.shade200,
                    label: 'Approved'.tr(context)),
                _LegendDot(
                    color: Colors.amber.shade200,
                    label: 'Pending'.tr(context)),
                _LegendDot(
                    color: AppColors.primaryMid,
                    label: 'Selected'.tr(context)),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Month Picker Grid View
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMonthPickerView(bool isAr) {
    final months = isAr ? _arMonths : _enMonths;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    final canGoPrev = _pickerYear > _minYear;
    final canGoNext = _pickerYear < _maxYear;

    return Column(
      children: [
        // ── Year header with arrows ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left,
                    color: canGoPrev
                        ? AppColors.primaryMid
                        : Colors.grey.shade300),
                onPressed:
                    canGoPrev ? () => setState(() => _pickerYear--) : null,
              ),
              GestureDetector(
                onTap: () => setState(() => _showMonthPicker = false),
                child: Text(
                  '$_pickerYear',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryMid,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: canGoNext
                        ? AppColors.primaryMid
                        : Colors.grey.shade300),
                onPressed:
                    canGoNext ? () => setState(() => _pickerYear++) : null,
              ),
            ],
          ),
        ),

        // ── Months grid ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isCurrentMonth =
                    _pickerYear == currentYear && month == currentMonth;
                final isSelectedMonth = _pickerYear == _focusedDay.year &&
                    month == _focusedDay.month;
                final isInRange = _isMonthInRange(_pickerYear, month);

                return Material(
                  color: isSelectedMonth
                      ? AppColors.primaryMid
                      : isCurrentMonth
                          ? AppColors.primaryMid.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isInRange ? () => _onMonthSelected(month) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isInRange
                              ? Colors.grey.withValues(alpha: 0.1)
                              : isSelectedMonth
                                  ? AppColors.primaryMid
                                  : isCurrentMonth
                                      ? AppColors.primaryMid
                                          .withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        months[index],
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: isSelectedMonth || isCurrentMonth
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: !isInRange
                              ? Colors.grey.shade300
                              : isSelectedMonth
                                  ? Colors.white
                                  : isCurrentMonth
                                      ? AppColors.primaryMid
                                      : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Calendar View
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCalendarView({
    required bool isAr,
    required List<Holiday> holidays,
    required dynamic holidaysState,
    required Set<int> disabledWeekdays,
    required Set<DateTime> holidayDates,
    required Set<String> bookedDates,
    required Map<String, BookedDay> bookedDaysByDate,
    required dynamic bookedState,
    required DateFormat dateFormat,
  }) {
    if (bookedState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMid),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final firstOfMonth =
            DateTime(_focusedDay.year, _focusedDay.month, 1);
        final lastOfMonth =
            DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
        final startOffset = (firstOfMonth.weekday % 7 + 1) % 7;
        final totalCells = startOffset + lastOfMonth.day;
        final weekRows = (totalCells / 7).ceil();
        final headerAndDow = 92.0;
        final availableHeight = constraints.maxHeight - headerAndDow;
        final rowH = (availableHeight / weekRows).clamp(48.0, 100.0);

        return TableCalendar(
          firstDay: _minDate,
          lastDay: _maxDate,
          focusedDay: _focusedDay,
          rowHeight: rowH,
          locale: 'en',
          startingDayOfWeek: StartingDayOfWeek.saturday,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) {
              final monthName = isAr
                  ? _arMonths[date.month - 1]
                  : DateFormat.MMMM('en').format(date);
              return '$monthName ${date.year}';
            },
            titleTextStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            leftChevronIcon: const Icon(Icons.chevron_left,
                color: AppColors.primaryMid),
            rightChevronIcon: const Icon(Icons.chevron_right,
                color: AppColors.primaryMid),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            ),
            weekendStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.appColors.textMuted,
            ),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primaryMid.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
            defaultTextStyle: TextStyle(
              fontFamily: 'Cairo',
              color: context.appColors.textPrimary,
            ),
            outsideTextStyle: TextStyle(
              fontFamily: 'Cairo',
              color: context.appColors.textDisabled,
            ),
            disabledTextStyle: TextStyle(
              fontFamily: 'Cairo',
              color:
                  context.appColors.textDisabled.withValues(alpha: 0.4),
            ),
            weekendTextStyle: TextStyle(
              fontFamily: 'Cairo',
              color: context.appColors.textPrimary,
            ),
            rangeStartDecoration: const BoxDecoration(
              color: AppColors.primaryMid,
              shape: BoxShape.circle,
            ),
            rangeEndDecoration: const BoxDecoration(
              color: AppColors.primaryMid,
              shape: BoxShape.circle,
            ),
            rangeHighlightColor:
                AppColors.primaryMid.withValues(alpha: 0.15),
            withinRangeTextStyle: TextStyle(
              fontFamily: 'Cairo',
              color: context.appColors.textPrimary,
            ),
          ),
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          rangeSelectionMode: RangeSelectionMode.toggledOff,
          enabledDayPredicate: (day) => !_isDayDisabled(
              day, disabledWeekdays, holidayDates, bookedDates),
          onDaySelected: (day, focusedDay) {
            _onDaySelected(
                day, disabledWeekdays, holidayDates, bookedDates);
            setState(() => _focusedDay = focusedDay);
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
            _loadBookedDays(focusedDay);
            final focusedYear = focusedDay.year;
            if (focusedYear != holidaysState.year) {
              ref.read(holidaysProvider.notifier).load(year: focusedYear);
            }
          },
          onHeaderTapped: (_) {
            // Switch to month picker view.
            setState(() {
              _pickerYear = _focusedDay.year;
              _showMonthPicker = true;
            });
          },
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) {
              const arDays = {
                6: 'السبت',
                7: 'الأحد',
                1: 'الاثنين',
                2: 'الثلاثاء',
                3: 'الأربعاء',
                4: 'الخميس',
                5: 'الجمعة',
              };
              final label = isAr
                  ? (arDays[day.weekday] ?? '')
                  : DateFormat.E('en').format(day);
              return Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textSecondary,
                  ),
                ),
              );
            },
            disabledBuilder: (context, day, focusedDay) {
              final normalized =
                  DateTime(day.year, day.month, day.day);
              final isHoliday = holidayDates.contains(normalized);
              final hName =
                  isHoliday ? _holidayName(day, holidays) : null;

              final dateStr =
                  DateFormat('yyyy-MM-dd', 'en').format(normalized);
              final bookedDay = bookedDaysByDate[dateStr];

              if (bookedDay != null) {
                return _buildBookedDayCell(day, bookedDay);
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isHoliday
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: isHoliday
                            ? Colors.red.shade300
                            : context.appColors.textDisabled,
                      ),
                    ),
                  ),
                  if (hName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        hName,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 7,
                          color: Colors.red.shade300,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Build a cell for a booked (approved/pending) day.
  Widget _buildBookedDayCell(DateTime day, BookedDay bookedDay) {
    final isApproved = bookedDay.isApproved;
    final bgColor = isApproved
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.amber.withValues(alpha: 0.15);
    final textColor =
        isApproved ? Colors.green.shade700 : Colors.amber.shade800;
    final label = bookedDay.leaveTypeName;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 7,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: context.appColors.textMuted,
            )),
      ],
    );
  }
}
