import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/attendance_models.dart';

/// Full-screen calendar picker for selecting an attendance date range.
///
/// مستوحى من `LeaveCalendarPicker` لكن أبسط:
/// - لا أيام إجازة أسبوعية معطّلة — الموظف قد يحضر يوم الجمعة فيجب أن يظهر.
/// - لا تحميل عطل رسمية مستقلّ — السيرفر يرسل سجلات الحضور مع `status`
///   فإذا كان اليوم عطلة (بدون حضور) لن يأتي سجل له فيُعرض افتراضياً.
/// - يلوّن كل خلية يوم وفق `status` للسجل المقابل من `/attendance/history`.
/// - تحميل lazy لكل شهر يتنقّل إليه المستخدم.
/// - لا يُسمح بأيام مستقبلية ([lastDay] = اليوم).
class AttendanceCalendarPicker extends ConsumerStatefulWidget {
  final DateTimeRange? initialRange;

  /// Pre-loaded records (typically: ما هو معروض الآن في الشاشة). يُفهرسها
  /// المنتقي مباشرة لتفادي طلب إضافي للشهر الحالي.
  final List<AttendanceRecord> initialRecords;

  const AttendanceCalendarPicker({
    super.key,
    this.initialRange,
    this.initialRecords = const [],
  });

  @override
  ConsumerState<AttendanceCalendarPicker> createState() =>
      _AttendanceCalendarPickerState();
}

class _AttendanceCalendarPickerState
    extends ConsumerState<AttendanceCalendarPicker> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  /// true = show month grid, false = show calendar.
  bool _showMonthPicker = false;

  /// Year displayed in the month picker grid.
  late int _pickerYear;

  /// Records indexed by date string `yyyy-MM-dd` (ASCII).
  final Map<String, AttendanceRecord> _recordsByDate = {};

  /// Months we've already fetched (`yyyy-MM`).
  final Set<String> _loadedMonths = {};

  /// True while a background fetch is in progress.
  bool _isFetching = false;

  // ── Bounds: من سنتين للوراء حتى اليوم (لا مستقبل) ──
  static final DateTime _today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  static final DateTime _minDate =
      DateTime(_today.year - 2, _today.month, _today.day);
  static final DateTime _maxDate = _today;

  static final int _minYear = _minDate.year;
  static final int _minMonth = _minDate.month;
  static final int _maxYear = _maxDate.year;
  static final int _maxMonth = _maxDate.month;

  bool _isMonthInRange(int year, int month) {
    if (year < _minYear || year > _maxYear) return false;
    if (year == _minYear && month < _minMonth) return false;
    if (year == _maxYear && month > _maxMonth) return false;
    return true;
  }

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

    // فهرس السجلات المُمرّرة لتفادي طلب إضافي.
    for (final r in widget.initialRecords) {
      _recordsByDate[r.date] = r;
    }
    // علّم الأشهر التي يغطّيها النطاق الابتدائي كـ "محمّلة".
    if (widget.initialRange != null) {
      _markMonthsLoaded(
          widget.initialRange!.start, widget.initialRange!.end);
    }

    // اضمن تحميل الشهر الحالي إن لم يكن قد حُمّل ضمن النطاق الابتدائي.
    Future.microtask(() => _ensureMonthLoaded(_focusedDay));
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _markMonthsLoaded(DateTime start, DateTime end) {
    var d = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!d.isAfter(endMonth)) {
      _loadedMonths.add(_monthKey(d));
      d = DateTime(d.year, d.month + 1, 1);
    }
  }

  /// يجلب سجلات الشهر إن لم يكن محمّلاً، ويُحدّث الـ index. صامت عند الفشل
  /// (الخلايا تظل بدون لون).
  Future<void> _ensureMonthLoaded(DateTime month) async {
    final key = _monthKey(month);
    if (_loadedMonths.contains(key)) return;

    final firstOfMonth = DateTime(month.year, month.month, 1);
    // لا تجلب أشهراً مستقبلية بالكامل.
    if (firstOfMonth.isAfter(_today)) {
      _loadedMonths.add(key);
      return;
    }
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);
    final effectiveEnd = lastOfMonth.isAfter(_today) ? _today : lastOfMonth;

    if (mounted) setState(() => _isFetching = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final data = await repo.getHistory(
        dateFrom: _dayKey(firstOfMonth),
        dateTo: _dayKey(effectiveEnd),
        perPage: 31,
      );
      if (!mounted) return;
      for (final r in data.records) {
        _recordsByDate[r.date] = r;
      }
      _loadedMonths.add(key);
    } catch (_) {
      // فشل صامت — التقويم سيُعرض بدون ألوان للشهر فقط.
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  AttendanceRecord? _recordFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _recordsByDate[_dayKey(normalized)];
  }

  /// خريطة `status` → لون. الأكواد التي ترجع `null` تُعرض بنمط افتراضي
  /// (مثل weekend/holiday بدون حضور).
  Color? _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.success;
      case 'late':
        return AppColors.warning;
      case 'absent':
        return AppColors.error;
      case 'on_leave':
      case 'leave':
        return AppColors.info;
      case 'pending':
        return AppColors.gold;
      case 'shortage':
        return const Color(0xFFEF5350);
      case 'early_departure':
        return const Color(0xFFFFB74D);
      case 'late_and_early':
        return const Color(0xFFFF9800);
      case 'incomplete':
        return Colors.grey;
      case 'weekend':
      case 'holiday':
      default:
        return null;
    }
  }

  /// تسميات قصيرة (حرفان عربيان) لتظهر تحت الرقم — اختصارات الحالات
  /// الأكثر دلالة. للحالات بدون لون نُرجع null فلا يظهر نص.
  String? _shortLabel(BuildContext context, String status) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    switch (status.toLowerCase()) {
      case 'present':
        return isAr ? 'حضور' : 'P';
      case 'late':
        return isAr ? 'تأخير' : 'L';
      case 'absent':
        return isAr ? 'غياب' : 'A';
      case 'on_leave':
      case 'leave':
        return isAr ? 'إجازة' : 'V';
      case 'pending':
        return isAr ? 'معلق' : '...';
      case 'shortage':
        return isAr ? 'نقص' : 'S';
      case 'early_departure':
        return isAr ? 'مبكر' : 'E';
      case 'late_and_early':
        return isAr ? 'تأخير+مبكر' : 'L+E';
      case 'incomplete':
        return isAr ? 'ناقص' : '?';
      default:
        return null;
    }
  }

  // ════════════════ Range selection ════════════════

  void _onDaySelected(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    // لا أيام مستقبلية.
    if (normalized.isAfter(_today)) return;

    if (_rangeStart == null || _rangeEnd != null) {
      // ابدأ نطاقاً جديداً.
      setState(() {
        _rangeStart = normalized;
        _rangeEnd = null;
      });
    } else {
      // الضغطة الثانية — رتّب البداية/النهاية تلقائياً.
      DateTime start = _rangeStart!;
      DateTime end = normalized;
      if (normalized.isBefore(start)) {
        end = start;
        start = normalized;
      }
      setState(() {
        _rangeStart = start;
        _rangeEnd = end;
      });
      // أغلق المنتقي بعد ربع ثانية لرؤية النطاق المختار قبل العودة.
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
      // نطاق ليوم واحد.
      Navigator.of(context)
          .pop(DateTimeRange(start: _rangeStart!, end: _rangeStart!));
    }
  }

  void _onMonthSelected(int month) {
    final newFocused = DateTime(_pickerYear, month, 1);
    setState(() {
      _focusedDay = newFocused;
      _showMonthPicker = false;
    });
    _ensureMonthLoaded(newFocused);
  }

  // ════════════════ Build ════════════════

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dateFormat = DateFormat('yyyy-MM-dd', 'en');

    return Scaffold(
      appBar: AppBar(
        title: Text('Select date range'.tr(context),
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
          // ── شريط ملخص النطاق ──
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

          // ── المحتوى: تقويم أو شبكة أشهر ──
          Expanded(
            child: _showMonthPicker
                ? _buildMonthPickerView(isAr)
                : _buildCalendarView(isAr),
          ),

          // ── Legend ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _LegendDot(
                    color: AppColors.success,
                    label: 'Present'.tr(context)),
                _LegendDot(
                    color: AppColors.warning, label: 'Late'.tr(context)),
                _LegendDot(
                    color: AppColors.error, label: 'Absent'.tr(context)),
                _LegendDot(
                    color: AppColors.info, label: 'Leave'.tr(context)),
                _LegendDot(
                    color: AppColors.gold, label: 'Pending'.tr(context)),
                _LegendDot(
                    color: const Color(0xFFEF5350),
                    label: 'Shortage'.tr(context)),
                _LegendDot(
                    color: AppColors.primaryMid,
                    label: 'Selected'.tr(context)),
              ],
            ),
          ),
          // مفتاح نقطة الزاوية — حالات طلب الإجازة المغطي لليوم.
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${'Corner dot'.tr(context)}:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textMuted,
                  ),
                ),
                _LegendDot(
                    color: AppColors.success,
                    label: 'Approved leave'.tr(context)),
                _LegendDot(
                    color: AppColors.gold,
                    label: 'Pending leave'.tr(context)),
                _LegendDot(
                    color: context.appColors.textMuted,
                    label: 'Rejected/cancelled leave'.tr(context)),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }

  // ════════════════ Month Picker Grid ════════════════

  Widget _buildMonthPickerView(bool isAr) {
    final months = isAr ? _arMonths : _enMonths;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    final canGoPrev = _pickerYear > _minYear;
    final canGoNext = _pickerYear < _maxYear;

    return Column(
      children: [
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

  // ════════════════ Calendar View ════════════════

  Widget _buildCalendarView(bool isAr) {
    return Stack(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final firstOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
          final lastOfMonth =
              DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
          final startOffset = (firstOfMonth.weekday % 7 + 1) % 7;
          final totalCells = startOffset + lastOfMonth.day;
          final weekRows = (totalCells / 7).ceil();
          const headerAndDow = 92.0;
          final availableHeight = constraints.maxHeight - headerAndDow;
          final rowH = (availableHeight / weekRows).clamp(56.0, 110.0);

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
                final monthName =
                    isAr ? _arMonths[date.month - 1] : _enMonths[date.month - 1];
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
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(
                fontFamily: 'Cairo',
                color: context.appColors.textPrimary,
              ),
              weekendTextStyle: TextStyle(
                fontFamily: 'Cairo',
                color: context.appColors.textPrimary,
              ),
              outsideTextStyle: TextStyle(
                fontFamily: 'Cairo',
                color: context.appColors.textDisabled,
              ),
              disabledTextStyle: TextStyle(
                fontFamily: 'Cairo',
                color: context.appColors.textDisabled.withValues(alpha: 0.4),
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryMid.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
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
            onDaySelected: (day, focusedDay) {
              _onDaySelected(day);
              setState(() => _focusedDay = focusedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _ensureMonthLoaded(focusedDay);
            },
            onHeaderTapped: (_) {
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
              // الخلية الافتراضية — نلوّنها وفق `status` السجل (إن وُجد).
              defaultBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: false, isToday: false),
              todayBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: false, isToday: true),
              outsideBuilder: (context, day, focusedDay) {
                return Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: context.appColors.textDisabled,
                    ),
                  ),
                );
              },
              // داخل نطاق محدد (بين البداية والنهاية).
              withinRangeBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day,
                      isSelected: false, isToday: false, isWithinRange: true),
              // نقطتا النطاق (start/end).
              rangeStartBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: true, isToday: false),
              rangeEndBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: true, isToday: false),
            ),
          );
        }),
        if (_isFetching)
          const Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryMid),
              ),
            ),
          ),
      ],
    );
  }

  /// لون **حالة طلب الإجازة** المغطي لليوم — نفس ألوان بانر الإجازة في
  /// كرت سجل الحضور: أخضر = موافق، ذهبي = معلق، رمادي = مرفوض/ملغي/مسودة.
  Color _leaveStatusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.gold;
      default: // rejected / cancelled / draft
        return context.appColors.textMuted;
    }
  }

  /// الخلية الموحّدة: تعرض رقم اليوم مع لون/تسمية مأخوذة من سجل الحضور
  /// لذلك اليوم (إن وُجد)، ونقطة زاوية صغيرة بلون حالة طلب الإجازة عندما
  /// يغطي اليومَ طلبُ إجازة (`on_leave != null`).
  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    bool isWithinRange = false,
  }) {
    final rec = _recordFor(day);
    final color = rec != null ? _colorForStatus(rec.status) : null;
    final label = rec != null ? _shortLabel(context, rec.status) : null;
    final leave = rec?.onLeave;

    // ── لون الخلفية + لون النص ──
    final Color bgColor;
    final Color textColor;
    if (isSelected) {
      bgColor = AppColors.primaryMid;
      textColor = Colors.white;
    } else if (color != null) {
      bgColor = color.withValues(alpha: 0.15);
      textColor = color;
    } else if (isToday) {
      bgColor = AppColors.primaryMid.withValues(alpha: 0.2);
      textColor = context.appColors.textPrimary;
    } else {
      bgColor = Colors.transparent;
      textColor = isWithinRange
          ? context.appColors.textPrimary
          : context.appColors.textPrimary;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: color != null && !isSelected
                    ? Border.all(
                        color: color.withValues(alpha: 0.6), width: 1)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            // ── نقطة الزاوية: مؤشر طلب إجازة يغطي اليوم ──
            // لونها = حالة الطلب (أخضر/ذهبي/رمادي)، وحولها حد بلون خلفية
            // الشاشة ليفصلها بصرياً عن دائرة اليوم مهما كان لونها.
            if (leave != null)
              PositionedDirectional(
                top: -2,
                start: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _leaveStatusColor(context, leave.status),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // نص الحالة يظهر دائماً (حتى لو اليوم محدد) — لون النص يبقى لون
        // الحالة لتفادي تعارض بصري مع دائرة التحديد الكحلية.
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color,
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
