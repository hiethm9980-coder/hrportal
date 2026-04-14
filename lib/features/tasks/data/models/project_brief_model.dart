import 'task_priority_model.dart';

/// A compact project representation used in the task filters dropdown and
/// related list views. The full project detail model will live under
/// features/projects when implemented.
class ProjectBrief {
  final int id;
  final String name;
  final String? code;
  final String? status;       // e.g. ACTIVE, ON_HOLD, DONE
  final String? statusLabel;  // Localized
  final String? statusColor;
  final TaskPriority? priority;

  const ProjectBrief({
    required this.id,
    required this.name,
    this.code,
    this.status,
    this.statusLabel,
    this.statusColor,
    this.priority,
  });

  factory ProjectBrief.fromJson(Map<String, dynamic> json) {
    // The backend may return the status either as a flat string or as a
    // nested object like `{code, label, color}`.
    String? status;
    String? statusLabel;
    String? statusColor;
    final statusRaw = json['status'];
    if (statusRaw is Map) {
      status = statusRaw['code']?.toString();
      statusLabel = statusRaw['label']?.toString();
      statusColor = statusRaw['color']?.toString();
    } else if (statusRaw != null) {
      status = statusRaw.toString();
    }

    return ProjectBrief(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      status: status,
      statusLabel: statusLabel,
      statusColor: statusColor,
      priority: TaskPriority.tryFromJson(json['priority']),
    );
  }
}

/// Wraps the GET /api/v1/projects response data.
class ProjectsListData {
  final List<ProjectBrief> projects;

  const ProjectsListData({required this.projects});

  factory ProjectsListData.fromJson(Map<String, dynamic> json) {
    // Backend may return under `projects` or directly as a list.
    final raw = json['projects'] ?? json['items'] ?? json['data'] ?? const [];
    if (raw is List) {
      final parsed = raw
          .whereType<Map>()
          .map((e) => ProjectBrief.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ProjectsListData(projects: parsed);
    }
    return const ProjectsListData(projects: []);
  }
}
