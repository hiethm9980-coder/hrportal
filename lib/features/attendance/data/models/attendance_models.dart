// ⚠️ API CONTRACT v1.0.0 — Fields match §10.2 and §10.3 exactly.

import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';

/// نوع الإجازة المرفق بحقل [AttendanceOnLeave.leaveType].
///
/// `color` يأتي من السيرفر كنص hex (مثل `#10b981`) — يُستخدم مباشرة لتلوين
/// سطر الإجازة في الواجهة فتتطابق الألوان مع إعدادات HR.
class LeaveTypeInfo extends Equatable {
  final int id;
  final String? code;     // "ANNUAL"
  final String? name;     // "إجازة سنوية"
  final String? nameEn;   // "Annual Leave"
  final String? color;    // "#10b981"
  final bool isPaid;

  const LeaveTypeInfo({
    required this.id,
    this.code,
    this.name,
    this.nameEn,
    this.color,
    this.isPaid = false,
  });

  factory LeaveTypeInfo.fromJson(Map<String, dynamic> json) {
    return LeaveTypeInfo(
      id: json['id'] as int,
      code: json['code'] as String?,
      name: json['name'] as String?,
      nameEn: json['name_en'] as String?,
      color: json['color'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'name_en': nameEn,
        'color': color,
        'is_paid': isPaid,
      };

  /// الاسم المناسب للغة: عربي → `name`، غير ذلك → `name_en` (مع fallback
  /// متبادل لو أحدهما غائب).
  String? localizedName(bool isAr) =>
      isAr ? (name ?? nameEn) : (nameEn ?? name);

  @override
  List<Object?> get props => [id];
}

/// طلب الإجازة الذي يغطي يوم حضور معيّن (حقل `on_leave`).
///
/// مستقل تماماً عن حالة الحضور — قد يكون الموظف غائباً ولديه إجازة معتمدة
/// (غياب مبرَّر) أو حاضراً رغم إجازته. السيرفر يُرفق الطلب **بأي حالة**
/// (`approved` / `pending` / `rejected` / `cancelled` / `draft`)، وعند
/// تداخل أكثر من طلب على نفس اليوم يصل الأهم فقط بالأولوية:
/// approved → pending → draft → rejected → cancelled.
class AttendanceOnLeave extends Equatable {
  final int id;
  final String? requestNumber;  // "LR-26-00031"
  final String status;          // approved|pending|rejected|cancelled|draft
  final String? startDate;      // "2026-06-10"
  final String? endDate;        // "2026-06-11"
  final String? startPeriod;    // full_day | first_half | second_half
  final String? endPeriod;
  final double totalDays;       // 2.0
  final String? reason;
  final LeaveTypeInfo? leaveType;

  const AttendanceOnLeave({
    required this.id,
    this.requestNumber,
    this.status = 'approved',
    this.startDate,
    this.endDate,
    this.startPeriod,
    this.endPeriod,
    this.totalDays = 0,
    this.reason,
    this.leaveType,
  });

  factory AttendanceOnLeave.fromJson(Map<String, dynamic> json) {
    return AttendanceOnLeave(
      id: json['id'] as int,
      requestNumber: json['request_number'] as String?,
      status: json['status'] as String? ?? 'approved',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      startPeriod: json['start_period'] as String?,
      endPeriod: json['end_period'] as String?,
      totalDays: (json['total_days'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String?,
      leaveType: json['leave_type'] != null
          ? LeaveTypeInfo.fromJson(json['leave_type'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_number': requestNumber,
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'start_period': startPeriod,
        'end_period': endPeriod,
        'total_days': totalDays,
        'reason': reason,
        'leave_type': leaveType?.toJson(),
      };

  @override
  List<Object?> get props => [id];
}

/// Single attendance record.
///
/// Contract: §10.2 AttendanceRecord
class AttendanceRecord extends Equatable {
  // ── Non-nullable ──
  final int id;
  final String date;              // Y-m-d
  final String status;            // present|absent|late|early_leave|late_and_early|leave|holiday|weekend
  final bool isScheduledWorkday;
  final int workedMinutes;
  final double workedHours;
  final int overtimeMinutes;
  final int lateMinutes;
  final int earlyDepartureMinutes;
  final int shortageMinutes;
  final bool isComplete;

  // ── Nullable ──
  final String? checkInTime;      // Y-m-d H:i:s
  final String? checkOutTime;     // Y-m-d H:i:s
  final String? checkInSource;    // biometric|web|mobile|manual|auto|import
  final String? checkOutSource;
  final String? scheduledStart;   // H:i:s
  final String? scheduledEnd;     // H:i:s
  final String? notes;

  /// الإجازة المعتمدة المغطية لهذا اليوم — `null` إن لا توجد. مستقلة عن
  /// [status]: تُعرض كسطر ثانٍ في الكرت ("حالة الإجازة") بدون المساس
  /// بشارة حالة الحضور.
  final AttendanceOnLeave? onLeave;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    required this.isScheduledWorkday,
    required this.workedMinutes,
    required this.workedHours,
    required this.overtimeMinutes,
    required this.lateMinutes,
    required this.earlyDepartureMinutes,
    required this.shortageMinutes,
    required this.isComplete,
    this.checkInTime,
    this.checkOutTime,
    this.checkInSource,
    this.checkOutSource,
    this.scheduledStart,
    this.scheduledEnd,
    this.notes,
    this.onLeave,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int,
      date: json['date'] as String,
      status: json['status'] as String,
      isScheduledWorkday: json['is_scheduled_workday'] as bool,
      workedMinutes: json['worked_minutes'] as int,
      workedHours: (json['worked_hours'] as num).toDouble(),
      overtimeMinutes: json['overtime_minutes'] as int,
      lateMinutes: json['late_minutes'] as int,
      earlyDepartureMinutes: json['early_departure_minutes'] as int,
      shortageMinutes: json['shortage_minutes'] as int,
      isComplete: json['is_complete'] as bool,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      checkInSource: json['check_in_source'] as String?,
      checkOutSource: json['check_out_source'] as String?,
      scheduledStart: json['scheduled_start'] as String?,
      scheduledEnd: json['scheduled_end'] as String?,
      notes: json['notes'] as String?,
      onLeave: json['on_leave'] != null
          ? AttendanceOnLeave.fromJson(
              json['on_leave'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'status': status,
        'is_scheduled_workday': isScheduledWorkday,
        'worked_minutes': workedMinutes,
        'worked_hours': workedHours,
        'overtime_minutes': overtimeMinutes,
        'late_minutes': lateMinutes,
        'early_departure_minutes': earlyDepartureMinutes,
        'shortage_minutes': shortageMinutes,
        'is_complete': isComplete,
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'check_in_source': checkInSource,
        'check_out_source': checkOutSource,
        'scheduled_start': scheduledStart,
        'scheduled_end': scheduledEnd,
        'notes': notes,
        'on_leave': onLeave?.toJson(),
      };

  @override
  List<Object?> get props => [id, date];
}

/// Summary statistics for an attendance history query.
///
/// Contract: §10.3 AttendanceSummary
///
/// All per-status day counters are returned by the backend and reflect the
/// **full date period** (NOT affected by an active `status` filter). The
/// new per-status fields (`pendingDays`, `shortageDays`, `earlyDepartureDays`,
/// `lateAndEarlyDays`, `incompleteDays`, `weekendDays`, `holidayDays`) were
/// added so the UI chips can show accurate counts without local counting.
/// Older backends that don't include these fields default to 0.
class AttendanceSummary extends Equatable {
  // ── الإجماليات الأساسية (موجودة من قديم) ──
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int leaveDays;
  final double totalWorkedHours;
  final double totalOvertimeHours;
  final int totalLateMinutes;

  // ── حقول per-status الجديدة (للـ chips الإضافية) ──
  final int pendingDays;
  final int shortageDays;
  final int earlyDepartureDays;
  final int lateAndEarlyDays;
  final int incompleteDays;
  final int weekendDays;
  final int holidayDays;

  // ── إجماليات زمنية إضافية ──
  /// إجمالي الدقائق التي عمل بها الموظف خلال الفترة كاملةً — int دقيق
  /// (بخلاف [totalWorkedHours] الذي مقرَّب). نستخدمه لعرض ساعات/دقائق
  /// المجموع بدقة في الهيدر.
  final int totalWorkedMinutes;
  final int totalEarlyDepartureMinutes;
  final int totalShortageMinutes;

  const AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.leaveDays,
    required this.totalWorkedHours,
    required this.totalOvertimeHours,
    required this.totalLateMinutes,
    this.pendingDays = 0,
    this.shortageDays = 0,
    this.earlyDepartureDays = 0,
    this.lateAndEarlyDays = 0,
    this.incompleteDays = 0,
    this.weekendDays = 0,
    this.holidayDays = 0,
    this.totalWorkedMinutes = 0,
    this.totalEarlyDepartureMinutes = 0,
    this.totalShortageMinutes = 0,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    // Helper: int parse safe — يقبل غياب الحقل تماماً (backward compatible
    // مع أجهزة الـ TestFlight/Play القديمة ضمن نفس backend).
    int i(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AttendanceSummary(
      totalDays: i('total_days'),
      presentDays: i('present_days'),
      absentDays: i('absent_days'),
      lateDays: i('late_days'),
      leaveDays: i('leave_days'),
      totalWorkedHours: (json['total_worked_hours'] as num?)?.toDouble() ?? 0,
      totalOvertimeHours:
          (json['total_overtime_hours'] as num?)?.toDouble() ?? 0,
      totalLateMinutes: i('total_late_minutes'),
      pendingDays: i('pending_days'),
      shortageDays: i('shortage_days'),
      earlyDepartureDays: i('early_departure_days'),
      lateAndEarlyDays: i('late_and_early_days'),
      incompleteDays: i('incomplete_days'),
      weekendDays: i('weekend_days'),
      holidayDays: i('holiday_days'),
      totalWorkedMinutes: i('total_worked_minutes'),
      totalEarlyDepartureMinutes: i('total_early_departure_minutes'),
      totalShortageMinutes: i('total_shortage_minutes'),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_days': totalDays,
        'present_days': presentDays,
        'absent_days': absentDays,
        'late_days': lateDays,
        'leave_days': leaveDays,
        'total_worked_hours': totalWorkedHours,
        'total_overtime_hours': totalOvertimeHours,
        'total_late_minutes': totalLateMinutes,
        'pending_days': pendingDays,
        'shortage_days': shortageDays,
        'early_departure_days': earlyDepartureDays,
        'late_and_early_days': lateAndEarlyDays,
        'incomplete_days': incompleteDays,
        'weekend_days': weekendDays,
        'holiday_days': holidayDays,
        'total_worked_minutes': totalWorkedMinutes,
        'total_early_departure_minutes': totalEarlyDepartureMinutes,
        'total_shortage_minutes': totalShortageMinutes,
      };

  @override
  List<Object?> get props => [totalDays, presentDays];
}

/// Parsed data from GET /attendance/history.
///
/// Contract: §5.3 — `{records, pagination, summary}`
class AttendanceHistoryData {
  final List<AttendanceRecord> records;
  final Pagination pagination;
  final AttendanceSummary summary;

  const AttendanceHistoryData({
    required this.records,
    required this.pagination,
    required this.summary,
  });

  factory AttendanceHistoryData.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryData(
      records: (json['records'] as List)
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
      summary: AttendanceSummary.fromJson(
          json['summary'] as Map<String, dynamic>),
    );
  }
}
