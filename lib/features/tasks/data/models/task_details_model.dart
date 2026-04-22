/// Rich payload for the Details tab on the task detail screen.
///
/// Endpoints:
///   GET    /api/v1/tasks/{id}
///   PATCH  /api/v1/tasks/{id}
///   DELETE /api/v1/tasks/{id}
///
/// The `GET` response wraps *two* top-level blocks inside `data`:
///
///   data:
///     task:        { full task record including path, team, counts, … }
///     permissions: { per-field edit flags + can_delete }
///
/// PATCH returns the same shape after applying the change (no extra GET
/// needed). DELETE is a simple ok/success envelope.
///
/// We keep this model separate from the lighter `Task` used by the list
/// / card widgets — the details tab needs every field and every flag, the
/// list gets away with a thinner projection.
library;

import 'inline_company_ref.dart';
import 'task_priority_model.dart';
import 'task_models.dart' show TaskStatusRef;

// ═══════════════════════════════════════════════════════════════════
// Sub-models
// ═══════════════════════════════════════════════════════════════════

/// Breadcrumb path from the root project down to the current task.
class TaskPath {
  final List<PathNode> nodes;
  final String label; // pre-joined "A / B / C / current"

  const TaskPath({this.nodes = const [], this.label = ''});

  factory TaskPath.fromJson(Map<String, dynamic> json) {
    final rawNodes = (json['nodes'] as List?) ?? const [];
    return TaskPath(
      nodes: rawNodes
          .whereType<Map>()
          .map((n) => PathNode.fromJson(Map<String, dynamic>.from(n)))
          .toList(),
      label: json['label']?.toString() ?? '',
    );
  }
}

class PathNode {
  /// `project` or `task`.
  final String type;
  final int id;
  final String name;
  final bool isCurrent;

  const PathNode({
    required this.type,
    required this.id,
    required this.name,
    this.isCurrent = false,
  });

  bool get isProject => type == 'project';
  bool get isTask => type == 'task';

  factory PathNode.fromJson(Map<String, dynamic> json) {
    return PathNode(
      type: json['type']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}

/// Minimal employee reference — `{id, code, name}`.
///
/// Server uses this shape for `task.assignee`, `project.manager`, and each
/// member of `team.project_members` (plus extra flags). We reuse one
/// canonical parser so every spot in the UI reads the same fields.
class SimpleEmployeeRef {
  final int id;
  final String? code;
  final String name;

  const SimpleEmployeeRef({
    required this.id,
    required this.name,
    this.code,
  });

  factory SimpleEmployeeRef.fromJson(Map<String, dynamic> json) {
    return SimpleEmployeeRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }

  static SimpleEmployeeRef? tryFromJson(Object? raw) {
    if (raw is Map) {
      return SimpleEmployeeRef.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// `created_by` / `updated_by` entry — includes both user_id and
/// employee_id because the backend treats those as separate tables.
class AuditActor {
  final int? userId;
  final int? employeeId;
  final String? code;
  final String name;

  const AuditActor({
    required this.name,
    this.userId,
    this.employeeId,
    this.code,
  });

  factory AuditActor.fromJson(Map<String, dynamic> json) {
    return AuditActor(
      userId: (json['user_id'] as num?)?.toInt(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      code: json['code']?.toString(),
      name: json['name']?.toString() ?? '',
    );
  }

  static AuditActor? tryFromJson(Object? raw) {
    if (raw is Map) return AuditActor.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// Project summary attached to the task — project id + name + manager.
class TaskProjectInfo {
  final int id;
  final String? code;
  final String name;
  final SimpleEmployeeRef? manager;

  const TaskProjectInfo({
    required this.id,
    required this.name,
    this.code,
    this.manager,
  });

  factory TaskProjectInfo.fromJson(Map<String, dynamic> json) {
    return TaskProjectInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      manager: SimpleEmployeeRef.tryFromJson(json['manager']),
    );
  }

  static TaskProjectInfo? tryFromJson(Object? raw) {
    if (raw is Map) {
      return TaskProjectInfo.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// One row of the `team.project_members` list — a project member plus
/// three boolean flags describing their role in THIS specific task.
/// Drives the checklist UI (checkbox + optional PM / assignee badges).
class TaskTeamMember {
  final int id;
  final String? code;
  final String name;
  final bool isTaskMember;
  final bool isTaskAssignee;
  final bool isProjectManager;

  const TaskTeamMember({
    required this.id,
    required this.name,
    this.code,
    this.isTaskMember = false,
    this.isTaskAssignee = false,
    this.isProjectManager = false,
  });

  factory TaskTeamMember.fromJson(Map<String, dynamic> json) {
    return TaskTeamMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      isTaskMember: json['is_task_member'] as bool? ?? false,
      isTaskAssignee: json['is_task_assignee'] as bool? ?? false,
      isProjectManager: json['is_project_manager'] as bool? ?? false,
    );
  }
}

/// `team` block — the full project roster + precomputed helpers
/// (`task_member_ids`, `assignee_id`) so the UI doesn't have to recompute
/// them from the member list.
class TaskTeam {
  final List<TaskTeamMember> projectMembers;
  final List<int> taskMemberIds;
  final int? assigneeId;

  const TaskTeam({
    this.projectMembers = const [],
    this.taskMemberIds = const [],
    this.assigneeId,
  });

  factory TaskTeam.fromJson(Map<String, dynamic> json) {
    final raw = (json['project_members'] as List?) ?? const [];
    final ids = (json['task_member_ids'] as List?) ?? const [];
    return TaskTeam(
      projectMembers: raw
          .whereType<Map>()
          .map((m) => TaskTeamMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      taskMemberIds: ids
          .map((e) => (e as num?)?.toInt())
          .whereType<int>()
          .toList(),
      assigneeId: (json['assignee_id'] as num?)?.toInt(),
    );
  }

  static TaskTeam tryFromJson(Object? raw) {
    if (raw is Map) return TaskTeam.fromJson(Map<String, dynamic>.from(raw));
    return const TaskTeam();
  }
}

/// `counts` block — shown as a 2×2 tappable grid in the Details tab.
/// Tapping any count should navigate to the corresponding sibling tab.
class TaskCounts {
  final int subtasks;
  final int comments;
  final int attachments;
  final int timeLogs;

  const TaskCounts({
    this.subtasks = 0,
    this.comments = 0,
    this.attachments = 0,
    this.timeLogs = 0,
  });

  factory TaskCounts.fromJson(Map<String, dynamic> json) {
    return TaskCounts(
      subtasks: (json['subtasks'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      attachments: (json['attachments'] as num?)?.toInt() ?? 0,
      timeLogs: (json['time_logs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One row in `status_time_breakdown` — how long the task sat in each
/// status over its lifetime. `duration_label` is pre-formatted by the
/// server (e.g. "3.8 يوم") so the UI displays it verbatim.
class StatusTimeBreakdown {
  final String code;
  final String label;
  final String color;
  final int durationMinutes;
  final String durationLabel;

  const StatusTimeBreakdown({
    required this.code,
    required this.label,
    required this.color,
    this.durationMinutes = 0,
    this.durationLabel = '',
  });

  factory StatusTimeBreakdown.fromJson(Map<String, dynamic> json) {
    return StatusTimeBreakdown(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      durationLabel: json['duration_label']?.toString() ?? '',
    );
  }
}

/// Fine-grained per-field edit permissions for the Details tab. Each
/// `can_edit_*` flag gates the matching edit icon + the edit sheet for
/// that field. `can_delete` gates the delete action at the top of the tab.
///
/// Distinct from the lighter `TaskPermissions` on the list `Task` model —
/// that one only carries the coarser `can_update_status` /
/// `can_update_progress` used by the task card.
class TaskDetailsPermissions {
  final bool canEditTitle;
  final bool canEditDescription;
  final bool canEditPriority;
  final bool canEditStatus;
  final bool canUpdateProgress;
  final bool canEditDueDate;
  final bool canEditMembers;
  final bool canChangeAssignee;
  final bool canDelete;

  // Shared with the list model — surfaced here too for convenience
  // (the FABs on sibling tabs also gate by these).
  final bool canCreateSubtask;
  final bool canComment;
  final bool canUploadAttachment;
  final bool canLogTime;

  const TaskDetailsPermissions({
    this.canEditTitle = false,
    this.canEditDescription = false,
    this.canEditPriority = false,
    this.canEditStatus = false,
    this.canUpdateProgress = false,
    this.canEditDueDate = false,
    this.canEditMembers = false,
    this.canChangeAssignee = false,
    this.canDelete = false,
    this.canCreateSubtask = false,
    this.canComment = false,
    this.canUploadAttachment = false,
    this.canLogTime = false,
  });

  factory TaskDetailsPermissions.fromJson(Map<String, dynamic> json) {
    return TaskDetailsPermissions(
      canEditTitle: json['can_edit_title'] as bool? ?? false,
      canEditDescription: json['can_edit_description'] as bool? ?? false,
      canEditPriority: json['can_edit_priority'] as bool? ?? false,
      canEditStatus: json['can_edit_status'] as bool? ?? false,
      canUpdateProgress: json['can_update_progress'] as bool? ?? false,
      canEditDueDate: json['can_edit_due_date'] as bool? ?? false,
      canEditMembers: json['can_edit_members'] as bool? ?? false,
      canChangeAssignee: json['can_change_assignee'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      canCreateSubtask: json['can_create_subtask'] as bool? ?? false,
      canComment: json['can_comment'] as bool? ?? false,
      canUploadAttachment:
          json['can_upload_attachment'] as bool? ?? false,
      canLogTime: json['can_log_time'] as bool? ?? false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TaskDetails — top-level
// ═══════════════════════════════════════════════════════════════════

class TaskDetails {
  final int id;
  final String? code;
  final String title;
  final String? description;

  final TaskStatusRef? status;
  final TaskPriority? priority;
  final int progressPercent;

  final String? startDate;       // yyyy-MM-dd
  final String? dueDate;
  final String? completionDate;
  final bool isOverdue;
  final bool isCompleted;

  final TaskPath path;
  final TaskProjectInfo? project;
  final SimpleEmployeeRef? assignee;
  /// Company that owns the task (for company-manager permission checks).
  final int? companyId;
  final TaskTeam team;

  final TaskCounts counts;
  final double totalTimeHours;
  final List<StatusTimeBreakdown> statusTimeBreakdown;

  final DateTime? createdAt;
  final AuditActor? createdBy;
  final DateTime? updatedAt;
  final AuditActor? updatedBy;

  final TaskDetailsPermissions permissions;

  const TaskDetails({
    required this.id,
    required this.title,
    this.code,
    this.description,
    this.status,
    this.priority,
    this.progressPercent = 0,
    this.startDate,
    this.dueDate,
    this.completionDate,
    this.isOverdue = false,
    this.isCompleted = false,
    this.path = const TaskPath(),
    this.project,
    this.assignee,
    this.companyId,
    this.team = const TaskTeam(),
    this.counts = const TaskCounts(),
    this.totalTimeHours = 0,
    this.statusTimeBreakdown = const [],
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.permissions = const TaskDetailsPermissions(),
  });

  /// Parse the full `data` block returned by `GET /tasks/{id}` —
  /// unwraps both `task` and the sibling `permissions` object.
  factory TaskDetails.fromJson(Map<String, dynamic> data) {
    final taskRaw = data['task'] is Map
        ? Map<String, dynamic>.from(data['task'] as Map)
        : <String, dynamic>{};
    final permRaw = data['permissions'] is Map
        ? Map<String, dynamic>.from(data['permissions'] as Map)
        : <String, dynamic>{};

    final breakdownRaw =
        (taskRaw['status_time_breakdown'] as List?) ?? const [];

    return TaskDetails(
      id: (taskRaw['id'] as num?)?.toInt() ?? 0,
      code: taskRaw['code']?.toString(),
      title: taskRaw['title']?.toString() ?? '',
      description: taskRaw['description']?.toString(),
      status: TaskStatusRef.tryFromJson(taskRaw['status']),
      priority: TaskPriority.tryFromJson(taskRaw['priority']),
      progressPercent:
          (taskRaw['progress_percent'] as num?)?.toInt() ?? 0,
      startDate: taskRaw['start_date']?.toString(),
      dueDate: taskRaw['due_date']?.toString(),
      completionDate: taskRaw['completion_date']?.toString(),
      isOverdue: taskRaw['is_overdue'] as bool? ?? false,
      isCompleted: taskRaw['is_completed'] as bool? ?? false,
      path: taskRaw['path'] is Map
          ? TaskPath.fromJson(Map<String, dynamic>.from(taskRaw['path']))
          : const TaskPath(),
      project: TaskProjectInfo.tryFromJson(taskRaw['project']),
      assignee: SimpleEmployeeRef.tryFromJson(taskRaw['assignee']),
      companyId: (taskRaw['company_id'] as num?)?.toInt() ??
          InlineCompanyRef.tryFromJson(taskRaw['company'])?.id,
      team: TaskTeam.tryFromJson(taskRaw['team']),
      counts: taskRaw['counts'] is Map
          ? TaskCounts.fromJson(Map<String, dynamic>.from(taskRaw['counts']))
          : const TaskCounts(),
      totalTimeHours:
          (taskRaw['total_time_hours'] as num?)?.toDouble() ?? 0,
      statusTimeBreakdown: breakdownRaw
          .whereType<Map>()
          .map((e) =>
              StatusTimeBreakdown.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: _parseDate(taskRaw['created_at']),
      createdBy: AuditActor.tryFromJson(taskRaw['created_by']),
      updatedAt: _parseDate(taskRaw['updated_at']),
      updatedBy: AuditActor.tryFromJson(taskRaw['updated_by']),
      permissions: TaskDetailsPermissions.fromJson(permRaw),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
