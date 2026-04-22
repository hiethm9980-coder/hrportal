/// Models for the Activity tab.
///
/// Endpoint:
///   GET /api/v1/tasks/{id}/activity
///
/// The server ships a single unified feed (`items`) that mixes two kinds:
///   - **status_change** — a rich status transition (from → to + actor +
///     duration) rendered as a tall card with two colored pills.
///   - **update** — a generic audit log row (comment added, attachment
///     uploaded, time logged, …) rendered as a compact list tile.
///
/// All timestamps are ISO-8601 with the server's UTC offset; UI must call
/// `.toLocal()` + `AppFuns.formatTime` before display. The items are
/// already sorted newest-first on the server.
library;

enum ActivityKind { statusChange, update }

/// Lightweight actor record attached to every activity row.
class ActivityActor {
  final int id;
  final String? code;
  final String name;

  const ActivityActor({
    required this.id,
    required this.name,
    this.code,
  });

  factory ActivityActor.fromJson(Map<String, dynamic> json) {
    return ActivityActor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }

  static ActivityActor? tryFromJson(Object? raw) {
    if (raw is Map) {
      return ActivityActor.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One of the two status pills in a status-change card — mirrors the chip
/// shape we already use on the task card.
class ActivityStatusChip {
  final String? code;
  final String? label;
  final String? color; // hex "#RRGGBB"

  const ActivityStatusChip({this.code, this.label, this.color});

  factory ActivityStatusChip.fromJson(Map<String, dynamic> json) {
    return ActivityStatusChip(
      code: json['code']?.toString(),
      label: json['label']?.toString(),
      color: json['color']?.toString(),
    );
  }

  static ActivityStatusChip? tryFromJson(Object? raw) {
    if (raw is Map) {
      return ActivityStatusChip.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// The `status_change` payload attached to kind=status_change items.
class ActivityStatusChange {
  final ActivityStatusChip? from;
  final ActivityStatusChip? to;

  /// How long the task sat in the previous status before the change.
  /// Pre-formatted by the server (e.g. "3 دقائق") so we don't re-render
  /// it here — just display the label as-is.
  final int? durationMinutes;
  final String? durationLabel;

  final String? notes;

  const ActivityStatusChange({
    this.from,
    this.to,
    this.durationMinutes,
    this.durationLabel,
    this.notes,
  });

  factory ActivityStatusChange.fromJson(Map<String, dynamic> json) {
    return ActivityStatusChange(
      from: ActivityStatusChip.tryFromJson(json['from']),
      to: ActivityStatusChip.tryFromJson(json['to']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      durationLabel: json['duration_label']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  static ActivityStatusChange? tryFromJson(Object? raw) {
    if (raw is Map) {
      return ActivityStatusChange.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One row in the unified activity feed.
class ActivityItem {
  /// Discriminator. Most fields are shared; only `statusChange` is
  /// populated when [kind] is [ActivityKind.statusChange].
  final ActivityKind kind;

  /// Unique key across both kinds — prefixed with `log-` or `status-` by
  /// the server. Use this verbatim for `ValueKey` in list builders.
  final String id;

  /// Server-side machine type (e.g. `comment_added`, `status_changed`).
  /// Drives the icon + localized label lookup.
  final String type;

  /// Localized title from the server (`"إضافة تعليق"`, `"تغيير الحالة"`).
  final String title;

  /// Localized description — often English placeholder for update rows,
  /// sometimes detailed Arabic for status changes. UI may or may not
  /// display it depending on layout.
  final String description;

  final ActivityActor? actor;
  final DateTime? createdAt;

  /// Only populated when [kind] == [ActivityKind.statusChange].
  final ActivityStatusChange? statusChange;

  const ActivityItem({
    required this.kind,
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.actor,
    this.createdAt,
    this.statusChange,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind']?.toString();
    final kind = rawKind == 'status_change'
        ? ActivityKind.statusChange
        : ActivityKind.update;
    return ActivityItem(
      kind: kind,
      // ID may come as string ("log-49") or int — coerce to string.
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      actor: ActivityActor.tryFromJson(json['actor']),
      createdAt: _parseDate(json['created_at']),
      statusChange: ActivityStatusChange.tryFromJson(json['status_change']),
    );
  }
}

/// Summary block shown at the top of the tab (total + per-kind counts).
class ActivitySummary {
  final int total;
  final int updatesCount;
  final int statusChangesCount;

  const ActivitySummary({
    this.total = 0,
    this.updatesCount = 0,
    this.statusChangesCount = 0,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      updatesCount: (json['updates_count'] as num?)?.toInt() ?? 0,
      statusChangesCount: (json['status_changes_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Complete payload returned by `GET /api/v1/tasks/{id}/activity`.
///
/// We ignore the server's `status_history` field — it's just the subset
/// of `items` where kind==status_change, which the UI can trivially
/// recompute if it needs a filtered view.
class ActivityData {
  final ActivitySummary summary;
  final List<ActivityItem> items;

  const ActivityData({
    this.summary = const ActivitySummary(),
    this.items = const [],
  });

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List?) ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ActivityData(
      summary: json['summary'] is Map
          ? ActivitySummary.fromJson(Map<String, dynamic>.from(json['summary']))
          : const ActivitySummary(),
      items: items,
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
