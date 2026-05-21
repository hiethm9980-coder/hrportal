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
import 'attendance_calendar_picker.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  /// مؤشّر الـ chip المختار. 0 = "All" (بلا فلتر حالة)؛ باقي المؤشرات
  /// تُخريط على [_statusMap] أدناه.
  int _tab = 0;
  DateTimeRange? _dateRange;

  /// قائمة الـ chips (بالترتيب). نُحافظ على الفهارس متطابقة بين الأسماء
  /// وأكواد الحالة والألوان والعدّادات لتسهيل القراءة.
  ///
  /// جميع العدّادات تأتي مباشرة من `summary` المرجَع من السيرفر — والـ
  /// summary يعكس الفترة الكاملة دائماً (لا يتأثر بفلتر الحالة)، فالأرقام
  /// تبقى ثابتة عند تبديل الـ chips.
  static const _labels = [
    'All', 'Present', 'Late', 'Absent', 'Leave', 'Pending', 'Shortage',
  ];
  static const _statusMap = <String?>[
    null, 'present', 'late', 'absent', 'on_leave', 'pending', 'shortage',
  ];
  static const _colors = [
    AppColors.teal,       // All
    AppColors.success,    // Present
    AppColors.warning,    // Late
    AppColors.error,      // Absent
    AppColors.info,       // Leave (on_leave)
    AppColors.gold,       // Pending
    Color(0xFFEF5350),    // Shortage — أحمر فاتح للتمييز عن "غياب"
  ];

  /// تنسيق تاريخ الـ API: `yyyy-MM-dd` بأرقام إنجليزية (ASCII) دائماً.
  /// نُجنّب Jiffy/intl هنا لأن locale عربي قد يُخرج أرقاماً عربية-هندية
  /// لا يقبلها السيرفر.
  String _apiDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_initDefaultRangeAndLoad);
  }

  /// الافتراضي: من بداية الشهر الحالي إلى اليوم.
  Future<void> _initDefaultRangeAndLoad() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _dateRange = DateTimeRange(start: startOfMonth, end: today);
    });
    _loadWithFilter();
  }

  void _loadWithFilter() {
    final ctrl = ref.read(attendanceHistoryProvider.notifier);
    final statusCode = _statusMap[_tab];
    // طلب واحد فقط بكلا الفلترين معاً — تجنّباً لـ double-load.
    ctrl.applyFilters(
      dateFrom: _dateRange != null ? _apiDate(_dateRange!.start) : null,
      dateTo: _dateRange != null ? _apiDate(_dateRange!.end) : null,
      statuses: statusCode == null ? const [] : [statusCode],
    );
  }

  /// منتقي النطاق المخصّص — يفتح تقويم مثل صفحة الإجازات، يعرض حالة كل
  /// يوم (حضور/تأخير/غياب/...) عبر `table_calendar` مع تحميل lazy للأشهر.
  Future<void> _pickDateRange() async {
    // نُمرّر السجلات المُحمَّلة حالياً للمنتقي ليتفادى طلب الشهر الحالي
    // مرّة ثانية. سجلات الأشهر الأخرى تُحمَّل عند التنقّل إليها.
    final state = ref.read(attendanceHistoryProvider);
    final picked = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AttendanceCalendarPicker(
          initialRange: _dateRange,
          initialRecords: state.items,
        ),
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadWithFilter();
    }
  }


  @override
  Widget build(BuildContext context) {
    // Check-in / Check-out: ابقَ مستمعاً لعرض الأخطاء/النجاحات كما كان.
    ref.listen<CheckActionState>(checkActionProvider, (prev, next) {
      final error = next.error;
      if (error != null) {
        GlobalErrorHandler.show(context, error);
        ref.read(checkActionProvider.notifier).clearError();
      }
      if (next.record != null && (prev?.record?.id != next.record!.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance record updated successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    final historyState = ref.watch(attendanceHistoryProvider);
    final summary = ref.read(attendanceHistoryProvider.notifier).summary;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          // ── Gradient Header (status pills + date-range button داخله) ──
          CustomAppBar(
            title: 'Attendance summary'.tr(context),
            leading: _buildTotalWorkedBadge(context, summary),
            onRefresh: () =>
                ref.read(attendanceHistoryProvider.notifier).refresh(),
            bottom: _buildFilterRow(context, summary),
          ),

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

  /// يبني شارة "إجمالي ساعات الدوام" التي تظهر في `leading` الهيدر —
  /// تستخدم `total_worked_minutes` (int دقيق) وتُنسّقها كـ "س د". تُخفى
  /// تماماً (SizedBox فارغ) قبل وصول summary أو عندما لا يوجد عمل، حتى
  /// لا تحتل مساحة فارغة في AppBar.
  Widget _buildTotalWorkedBadge(BuildContext context, AttendanceSummary? s) {
    if (s == null || s.totalWorkedMinutes <= 0) {
      return const SizedBox(width: 36);
    }
    final formatted =
        _formatTotalMinutes(context, s.totalWorkedMinutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            formatted,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// تنسيق "X س Y د" من دقائق int (ASCII دائماً).
  String _formatTotalMinutes(BuildContext context, int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final hLabel = 'h'.tr(context);
    final mLabel = 'm'.tr(context);
    if (m == 0) return '‏$h $hLabel';
    return '‏$h $hLabel $m $mLabel';
  }

  /// شريط الفلاتر داخل الهيدر: chips للحالة + زر اختيار النطاق الزمني.
  ///
  /// كل عدّادات الـ chips تأتي مباشرة من `summary` الذي يعكس كامل الفترة
  /// الزمنية (مستقلّ عن فلتر الحالة). فلا حساب محلي ولا "--" بعد الآن.
  Widget _buildFilterRow(BuildContext context, AttendanceSummary? s) {
    int? countFor(int index) {
      if (s == null) return null; // أثناء التحميل الأول.
      switch (index) {
        case 0: return s.totalDays;
        case 1: return s.presentDays;
        case 2: return s.lateDays;
        case 3: return s.absentDays;
        case 4: return s.leaveDays;
        case 5: return s.pendingDays;
        case 6: return s.shortageDays;
      }
      return null;
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_labels.length, (i) {
              final n = countFor(i);
              final v = n != null ? '$n' : '...';
              return Padding(
                padding: EdgeInsetsDirectional.only(
                    end: i < _labels.length - 1 ? 6 : 0),
                child: _filterPill(v, _labels[i].tr(context), _colors[i], i),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        _buildDateRangeRow(context),
      ],
    );
  }

  Widget _buildDateRangeRow(BuildContext context) {
    // النطاق الزمني إجباري ومضبوط افتراضياً من initState (شهر مايو حتى
    // اليوم). الضغط يفتح المنتقي فقط — لا يوجد زر إلغاء لأن المستخدم
    // لا يجب أن يبقى بلا نطاق محدد.
    final hasRange = _dateRange != null;
    final label = hasRange
        ? '${AppFuns.formatDate(_dateRange!.start, withDay: false)}  →  ${AppFuns.formatDate(_dateRange!.end, withDay: false)}'
        : 'Filter by date'.tr(context);

    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.date_range_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String count, String label, Color accentColor, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () {
        if (_tab == index) return;
        setState(() => _tab = index);
        _loadWithFilter();
      },
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accentColor,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AttendanceRecord record;
  const _RecordTile({required this.record});

  /// خريطة حالة الحضور → نوع `StatusBadge`. الألوان مطابقة لـ chips
  /// الموجودة في الهيدر (`_colors` في `_AttendanceScreenState`).
  String _statusType(String status) {
    switch (status.toLowerCase()) {
      case 'present':         return 'success';   // أخضر — نفس chip "حضور"
      case 'late':            return 'warning';   // برتقالي — نفس chip "تأخير"
      case 'late_and_early':  return 'warning';   // برتقالي
      case 'early_departure': return 'warning';   // برتقالي
      case 'absent':          return 'error';     // أحمر — نفس chip "غياب"
      case 'on_leave':
      case 'leave':           return 'info';      // أزرق — نفس chip "إجازة"
      case 'pending':         return 'gold';      // ذهبي — نفس chip "معلق"
      case 'shortage':        return 'shortage';  // أحمر فاتح — نفس chip "نقص"
      case 'holiday':         return 'navy';      // كحلي
      case 'weekend':         return 'navy';      // كحلي
      case 'incomplete':      return 'info';
      default:                return 'info';
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
      case 'pending':
        return 'Pending';
      case 'shortage':
        return 'Shortage';
      case 'holiday':
        return 'Holiday';
      default:
        return status;
    }
  }

  /// \u062A\u0646\u0633\u064A\u0642 "X \u0633\u0627\u0639\u0629 Y \u062F\u0642\u064A\u0642\u0629" \u2014 \u0646\u0623\u062E\u0630 \u0627\u0644\u062F\u0642\u0627\u0626\u0642 \u0627\u0644\u0625\u062C\u0645\u0627\u0644\u064A\u0629 (int \u062F\u0642\u064A\u0642) \u0628\u062F\u0644
  /// \u0627\u0644\u0633\u0627\u0639\u0627\u062A (double \u062A\u0642\u0631\u064A\u0628\u064A). \u0645\u062B\u0627\u0644: 544 \u062F\u0642\u064A\u0642\u0629 \u2192 "9\u0633 4\u062F" \u0648\u0644\u064A\u0633 "9\u0633 6\u062F"
  /// (\u0627\u0644\u0630\u064A \u064A\u062D\u062F\u062B \u0644\u0648 \u062D\u0633\u0628\u0646\u0627 \u0645\u0646 `worked_hours = 9.1` \u0627\u0644\u062A\u0642\u0631\u064A\u0628\u064A).
  String _formatWorkedHours(BuildContext context, int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
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
                value: AppFuns.formatApiDateTime(record.checkInTime!, withSeconds: true),
              ),
            if (record.checkOutTime != null)
              _AttendanceDetailRow(
                icon: '⏹',
                label: 'Check out'.tr(context),
                value: AppFuns.formatApiDateTime(record.checkOutTime!, withSeconds: true),
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
    // نوع الـ badge يُشتق من خريطة [_statusType] الموحَّدة (نفس ألوان chips
    // الهيدر) بدلاً من شرط ثنائي قديم.
    final statusType = _statusType(record.status);
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
                if (record.workedMinutes > 0)
                  Text(
                    _formatWorkedHours(context, record.workedMinutes),
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
