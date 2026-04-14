/// Represents a task / project priority.
///
/// The backend exposes priorities as `{code, label, color}` objects. Same
/// shape is used for projects and tasks, so a single model serves both.
class TaskPriority {
  final String code;   // LOW | MEDIUM | HIGH | CRITICAL
  final String label;  // Localized label
  final String color;  // Hex color

  const TaskPriority({
    required this.code,
    required this.label,
    required this.color,
  });

  factory TaskPriority.fromJson(Map<String, dynamic> json) {
    return TaskPriority(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
    );
  }

  static TaskPriority? tryFromJson(Object? raw) {
    if (raw is Map) return TaskPriority.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}
