/// Models for the Time Logs tab on the task detail screen.
///
/// Endpoint: `GET /api/v1/tasks/{id}/time-logs`
///
/// Response shape (summary):
/// ```
/// {
///   "summary":          { total_hours, logs_count, can_add_time_log },
///   "status_breakdown": { active, today, statuses: [{code,label,color,count,hours}] },
///   "time_logs":        [ TimeLog, ... ]
/// }
/// ```
///
/// The backend does ALL the heavy lifting:
/// - Status of each log (`in_range` / `overdue` / `upcoming`) is computed
///   server-side and exposed as `status.code/label/color` — never compute it
///   on the client.
/// - `range_label` is a ready-to-display string (`"2026-04-15"` or
///   `"2026-04-09 → 2026-04-12"`).
/// - `summary.total_hours` + `logs_count` respect the active filters (search,
///   status, date window). Just show them as-is.
/// - `can_delete` is per-log; `can_add_time_log` is per-screen. Trust them.

/// Inline employee ref embedded in a time log entry.
class TimeLogEmployee {
  final int id;
  final String name;
  final String? code;
  final String? avatarUrl;

  const TimeLogEmployee({
    required this.id,
    required this.name,
    this.code,
    this.avatarUrl,
  });

  factory TimeLogEmployee.fromJson(Map<String, dynamic> json) {
    return TimeLogEmployee(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      avatarUrl:
          json['avatar']?.toString() ?? json['avatar_url']?.toString(),
    );
  }

  static TimeLogEmployee? tryFromJson(Object? raw) {
    if (raw is Map) return TimeLogEmployee.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// Range status of a single log — computed server-side from (`date_from`,
/// `date_to`, today).
class TimeLogStatus {
  final String code;   // all | in_range | overdue | upcoming
  final String label;  // localized by the server
  final String color;  // hex

  const TimeLogStatus({
    required this.code,
    required this.label,
    required this.color,
  });

  factory TimeLogStatus.fromJson(Map<String, dynamic> json) {
    return TimeLogStatus(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
    );
  }

  static TimeLogStatus? tryFromJson(Object? raw) {
    if (raw is Map) return TimeLogStatus.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// A single time log row.
class TimeLog {
  final int id;
  final String? logDate;        // yyyy-MM-dd
  final String? dateFrom;       // yyyy-MM-dd
  final String? dateTo;         // yyyy-MM-dd (may equal dateFrom)
  final String rangeLabel;      // ready-to-display
  final double hoursSpent;
  final String? description;
  final TimeLogEmployee? employee;
  final String? createdAt;
  final TimeLogStatus? status;
  final bool canDelete;

  const TimeLog({
    required this.id,
    required this.rangeLabel,
    required this.hoursSpent,
    this.logDate,
    this.dateFrom,
    this.dateTo,
    this.description,
    this.employee,
    this.createdAt,
    this.status,
    this.canDelete = false,
  });

  factory TimeLog.fromJson(Map<String, dynamic> json) {
    return TimeLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      logDate: json['log_date']?.toString(),
      dateFrom: json['date_from']?.toString(),
      dateTo: json['date_to']?.toString(),
      rangeLabel: json['range_label']?.toString() ?? '',
      hoursSpent: (json['hours_spent'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      employee: TimeLogEmployee.tryFromJson(json['employee']),
      createdAt: json['created_at']?.toString(),
      status: TimeLogStatus.tryFromJson(json['status']),
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }
}

/// Top-level summary card.
class TimeLogSummary {
  final double totalHours;
  final int logsCount;
  final bool canAddTimeLog;

  const TimeLogSummary({
    this.totalHours = 0,
    this.logsCount = 0,
    this.canAddTimeLog = false,
  });

  factory TimeLogSummary.fromJson(Map<String, dynamic> json) {
    return TimeLogSummary(
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
      logsCount: (json['logs_count'] as num?)?.toInt() ?? 0,
      canAddTimeLog: json['can_add_time_log'] as bool? ?? false,
    );
  }
}

/// One Chip in the status breakdown row.
class TimeLogStatusEntry {
  final String code;
  final String label;
  final String color;
  final int count;
  final double hours;

  const TimeLogStatusEntry({
    required this.code,
    required this.label,
    required this.color,
    required this.count,
    required this.hours,
  });

  factory TimeLogStatusEntry.fromJson(Map<String, dynamic> json) {
    return TimeLogStatusEntry(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
      count: (json['count'] as num?)?.toInt() ?? 0,
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full status breakdown row (includes active + today to avoid computing
/// "now" on the client).
class TimeLogStatusBreakdown {
  final String active;      // code of the active chip, defaults to "all"
  final String today;       // yyyy-MM-dd — the server's view of "today"
  final List<TimeLogStatusEntry> statuses;

  const TimeLogStatusBreakdown({
    this.active = 'all',
    this.today = '',
    this.statuses = const [],
  });

  factory TimeLogStatusBreakdown.fromJson(Map<String, dynamic> json) {
    final list = (json['statuses'] as List?) ?? const [];
    final parsed = list
        .whereType<Map>()
        .map(
          (e) => TimeLogStatusEntry.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
    return TimeLogStatusBreakdown(
      active: json['active']?.toString() ?? 'all',
      today: json['today']?.toString() ?? '',
      statuses: parsed,
    );
  }
}

/// Complete payload returned by `GET /api/v1/tasks/{id}/time-logs`.
class TimeLogsData {
  final TimeLogSummary summary;
  final TimeLogStatusBreakdown statusBreakdown;
  final List<TimeLog> logs;

  const TimeLogsData({
    this.summary = const TimeLogSummary(),
    this.statusBreakdown = const TimeLogStatusBreakdown(),
    this.logs = const [],
  });

  factory TimeLogsData.fromJson(Map<String, dynamic> json) {
    final raw = (json['time_logs'] as List?) ?? const [];
    final logs = raw
        .whereType<Map>()
        .map((e) => TimeLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return TimeLogsData(
      summary: json['summary'] is Map
          ? TimeLogSummary.fromJson(Map<String, dynamic>.from(json['summary']))
          : const TimeLogSummary(),
      statusBreakdown: json['status_breakdown'] is Map
          ? TimeLogStatusBreakdown.fromJson(
              Map<String, dynamic>.from(json['status_breakdown']))
          : const TimeLogStatusBreakdown(),
      logs: logs,
    );
  }
}
