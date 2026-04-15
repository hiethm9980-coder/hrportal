import 'task_models.dart';

/// Permissions flags returned alongside a subtasks payload — dictate which
/// actions the current user can perform on the parent task.
class SubtasksPermissions {
  final bool canManage;
  final bool canUpdateStatus;
  final bool canUpdateProgress;
  final bool canCreateSubtask;

  const SubtasksPermissions({
    this.canManage = false,
    this.canUpdateStatus = false,
    this.canUpdateProgress = false,
    this.canCreateSubtask = false,
  });

  factory SubtasksPermissions.fromJson(Map<String, dynamic> json) {
    return SubtasksPermissions(
      canManage: json['can_manage'] as bool? ?? false,
      canUpdateStatus: json['can_update_status'] as bool? ?? false,
      canUpdateProgress: json['can_update_progress'] as bool? ?? false,
      canCreateSubtask: json['can_create_subtask'] as bool? ?? false,
    );
  }
}

/// Complete response payload for `GET /api/v1/tasks/{id}/subtasks`.
///
/// - [parent] carries the parent task's header fields (title, status, progress,
///   counts) so the detail header has everything it needs without a second
///   request.
/// - [subtasks] is a flat list. Tree expansion is handled client-side via the
///   `has_subtasks` / `subtasks_count` flags on each entry (Lazy Loading).
/// - [statusBreakdown] is NOT affected by the status filter.
class SubtasksData {
  final Task parent;
  final TaskStats stats;
  final StatusBreakdown statusBreakdown;
  final List<Task> subtasks;
  final PaginationInfo pagination;
  final SubtasksPermissions permissions;

  const SubtasksData({
    required this.parent,
    this.stats = const TaskStats(),
    this.statusBreakdown = const StatusBreakdown(),
    this.subtasks = const [],
    this.pagination = const PaginationInfo(),
    this.permissions = const SubtasksPermissions(),
  });

  factory SubtasksData.fromJson(Map<String, dynamic> json) {
    // Parent can come under `parent` (canonical) or `task` (legacy alias).
    final parentRaw = (json['parent'] ?? json['task']) as Map?;
    final parent = parentRaw != null
        ? Task.fromJson(Map<String, dynamic>.from(parentRaw))
        : const Task(id: 0, title: '');

    // Subtasks list can come under `subtasks` or `items`.
    final listRaw = (json['subtasks'] ?? json['items']) as List? ?? const [];
    final subtasks = listRaw
        .whereType<Map>()
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SubtasksData(
      parent: parent,
      subtasks: subtasks,
      stats: json['stats'] is Map
          ? TaskStats.fromJson(Map<String, dynamic>.from(json['stats']))
          : const TaskStats(),
      statusBreakdown: json['status_breakdown'] is Map
          ? StatusBreakdown.fromJson(
              Map<String, dynamic>.from(json['status_breakdown']))
          : const StatusBreakdown(),
      pagination: json['pagination'] is Map
          ? PaginationInfo.fromJson(Map<String, dynamic>.from(json['pagination']))
          : const PaginationInfo(),
      permissions: json['permissions'] is Map
          ? SubtasksPermissions.fromJson(
              Map<String, dynamic>.from(json['permissions']))
          : const SubtasksPermissions(),
    );
  }
}
