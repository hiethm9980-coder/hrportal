import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/leave_models.dart';

/// Full-screen calendar picker for filtering existing leave requests by
/// date range — يعرض كل أيام الموظف التي عليها طلب إجازة ملوّنة بحسب
/// حالة الطلب (موافق/معلق/مرفوض/مسودة/ملغي)، ويتيح اختيار نطاق تصفية.
///
/// مشابه بنيوياً لـ [AttendanceCalendarPicker]، مع فروقات منطقية:
/// - كل إجازة هي **نطاق تواريخ** (start → end)، ليس يوماً واحداً، فنُوسّعها
///   لخلايا متعددة عند الفهرسة.
/// - يُسمح بأيام مستقبلية (المستخدم قد يفلتر إجازات قادمة معتمدة).
/// - حد ±2 سنة من اليوم (كما في الـ Material picker الذي يستبدله).
class LeaveFilterCalendarPicker extends ConsumerStatefulWidget {
  final DateTimeRange? initialRange;

  /// Pre-loaded leaves (typically: الإجازات المعروضة في الشاشة الحالية)
  /// لتفادي طلب إضافي للنطاق الافتراضي.
  final List<LeaveRequest> initialLeaves;

  const LeaveFilterCalendarPicker({
    super.key,
    this.initialRange,
    this.initialLeaves = const [],
  });

  @override
  ConsumerState<LeaveFilterCalendarPicker> createState() =>
      _LeaveFilterCalendarPickerState();
}

class _LeaveFilterCalendarPickerState
    extends ConsumerState<LeaveFilterCalendarPicker> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  bool _showMonthPicker = false;
  late int _pickerYear;

  /// كل يوم → الإجازة التي تشمله (إن وُجدت). إن تقاطعت إجازتان (نادر)
  /// نحتفظ بالأحدث (آخر إجازة قُرئت).
  final Map<String, LeaveRequest> _leavesByDate = {};

  /// الأشهر التي حُمّلت (`yyyy-MM`).
  final Set<String> _loadedMonths = {};

  bool _isFetching = false;

  // ── Bounds: ±2 سنة من اليوم (يطابق الـ picker القديم) ──
  static final DateTime _today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  static final DateTime _minDate =
      DateTime(_today.year - 2, _today.month, _today.day);
  static final DateTime _maxDate =
      DateTime(_today.year + 2, _today.month, _today.day);

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

    // فهرس الإجازات الأولية على مستوى الأيام.
    for (final lv in widget.initialLeaves) {
      _indexLeave(lv);
    }
    if (widget.initialRange != null) {
      _markMonthsLoaded(
          widget.initialRange!.start, widget.initialRange!.end);
    }
    Future.microtask(() => _ensureMonthLoaded(_focusedDay));
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// يُوسّع نطاق إجازة لكل يوم بداخله ويضيفه للفهرس.
  void _indexLeave(LeaveRequest lv) {
    final start = DateTime.tryParse(lv.startDate);
    final end = DateTime.tryParse(lv.endDate);
    if (start == null) return;
    final endDate = end ?? start;
    var d = DateTime(start.year, start.month, start.day);
    final stop = DateTime(endDate.year, endDate.month, endDate.day);
    while (!d.isAfter(stop)) {
      _leavesByDate[_dayKey(d)] = lv;
      d = d.add(const Duration(days: 1));
    }
  }

  void _markMonthsLoaded(DateTime start, DateTime end) {
    var d = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!d.isAfter(endMonth)) {
      _loadedMonths.add(_monthKey(d));
      d = DateTime(d.year, d.month + 1, 1);
    }
  }

  /// يجلب إجازات الشهر إن لم يكن محمّلاً، صامت عند الفشل.
  Future<void> _ensureMonthLoaded(DateTime month) async {
    final key = _monthKey(month);
    if (_loadedMonths.contains(key)) return;

    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);

    if (mounted) setState(() => _isFetching = true);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      // نطلب كل الإجازات في الشهر بغض النظر عن الحالة — للسماح بتلوين
      // مرفوض/مسودة/ملغي كذلك. حد المخدم العلوي 50 سجلاً للصفحة كافٍ
      // لشهر واحد (نادر أن يتجاوز موظف ذلك).
      final data = await repo.getLeaves(
        dateFrom: _dayKey(firstOfMonth),
        dateTo: _dayKey(lastOfMonth),
        perPage: 50,
      );
      if (!mounted) return;
      for (final lv in data.requests) {
        _indexLeave(lv);
      }
      _loadedMonths.add(key);
    } catch (_) {
      // فشل صامت — الشهر سيبقى بدون ألوان.
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  LeaveRequest? _leaveFor(DateTime day) {
    return _leavesByDate[_dayKey(day)];
  }

  /// خريطة حالة الإجازة → لون.
  Color? _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      case 'draft':
        return AppColors.primaryMid;
      case 'cancelled':
        return Colors.grey;
      default:
        return null;
    }
  }

  /// نص اختصاري عربي/إنجليزي تحت رقم اليوم.
  String? _shortLabel(BuildContext context, String status) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    switch (status.toLowerCase()) {
      case 'approved':
        return isAr ? 'موافق' : 'OK';
      case 'pending':
        return isAr ? 'معلق' : '...';
      case 'rejected':
        return isAr ? 'مرفوض' : 'X';
      case 'draft':
        return isAr ? 'مسودة' : 'D';
      case 'cancelled':
        return isAr ? 'ملغي' : 'C';
      default:
        return null;
    }
  }

  // ════════════════ Range selection ════════════════

  void _onDaySelected(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (_rangeStart == null || _rangeEnd != null) {
      setState(() {
        _rangeStart = normalized;
        _rangeEnd = null;
      });
    } else {
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
                    label: 'Approved'.tr(context)),
                _LegendDot(
                    color: AppColors.warning,
                    label: 'Pending'.tr(context)),
                _LegendDot(
                    color: AppColors.error,
                    label: 'Rejected'.tr(context)),
                _LegendDot(
                    color: AppColors.primaryMid,
                    label: 'Draft'.tr(context)),
                _LegendDot(color: Colors.grey, label: 'Cancelled'.tr(context)),
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
          final firstOfMonth =
              DateTime(_focusedDay.year, _focusedDay.month, 1);
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
              withinRangeBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day,
                      isSelected: false, isToday: false, isWithinRange: true),
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

  /// خلية اليوم: تعرض الرقم + اختصار حالة الإجازة (إن وُجدت).
  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    bool isWithinRange = false,
  }) {
    final lv = _leaveFor(day);
    final color = lv != null ? _colorForStatus(lv.status) : null;
    final label = lv != null ? _shortLabel(context, lv.status) : null;

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
      textColor = context.appColors.textPrimary;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: color != null && !isSelected
                ? Border.all(color: color.withValues(alpha: 0.6), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight:
                  isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        // نص الحالة يظهر دائماً (حتى لو اليوم محدد) — بلون الحالة الأصلية
        // لتفادي تعارض بصري مع دائرة التحديد الكحلية.
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
