/// Represents a task status as returned by GET /api/v1/tasks/statuses.
///
/// Used for:
/// - Building status filter chips in the header.
/// - Displaying status in task cards.
/// - Changing task status via PATCH /api/v1/tasks/{id}/status.
class TaskStatus {
  final int id;
  final String code;      // TODO | IN_PROGRESS | REVIEW | HOLD | DONE | ...
  final String label;     // Localized label from server (Arabic by default)
  final String labelEn;   // English label
  final String category;  // OPEN | IN_PROGRESS | REVIEW | HOLD | DONE
  final String color;     // Hex color (e.g. "#22C55E")
  final int position;     // Display order
  final bool isDefault;   // Whether this is the default status for new tasks

  const TaskStatus({
    required this.id,
    required this.code,
    required this.label,
    required this.labelEn,
    required this.category,
    required this.color,
    required this.position,
    this.isDefault = false,
  });

  factory TaskStatus.fromJson(Map<String, dynamic> json) {
    return TaskStatus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      labelEn: json['label_en']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OPEN',
      color: json['color']?.toString() ?? '#9E9E9E',
      position: (json['position'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

/// Wraps the `/api/v1/tasks/statuses` response data.
class TaskStatusesData {
  final List<TaskStatus> statuses;

  const TaskStatusesData({required this.statuses});

  factory TaskStatusesData.fromJson(Map<String, dynamic> json) {
    final list = (json['statuses'] as List?) ?? const [];
    final parsed = list
        .whereType<Map>()
        .map((e) => TaskStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return TaskStatusesData(statuses: parsed);
  }
}
