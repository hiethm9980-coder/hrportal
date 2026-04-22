import 'inline_company_ref.dart';
import 'task_priority_model.dart';

/// Inline project reference embedded in task payloads.
class TaskProjectRef {
  final int id;
  final String name;
  final String? code;

  const TaskProjectRef({required this.id, required this.name, this.code});

  factory TaskProjectRef.fromJson(Map<String, dynamic> json) {
    return TaskProjectRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }

  static TaskProjectRef? tryFromJson(Object? raw) {
    if (raw is Map) return TaskProjectRef.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// Inline status reference embedded in task payloads.
class TaskStatusRef {
  final int id;
  final String code;
  final String label;
  final String color;
  final String? category;

  const TaskStatusRef({
    required this.id,
    required this.code,
    required this.label,
    required this.color,
    this.category,
  });

  factory TaskStatusRef.fromJson(Map<String, dynamic> json) {
    return TaskStatusRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
      category: json['category']?.toString(),
    );
  }

  static TaskStatusRef? tryFromJson(Object? raw) {
    if (raw is Map) return TaskStatusRef.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// Inline assignee reference.
class TaskAssigneeRef {
  final int id;
  final String name;
  final String? avatarUrl;

  const TaskAssigneeRef({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory TaskAssigneeRef.fromJson(Map<String, dynamic> json) {
    return TaskAssigneeRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
    );
  }

  static TaskAssigneeRef? tryFromJson(Object? raw) {
    if (raw is Map) return TaskAssigneeRef.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }
}

/// Per-task permission flags returned by the backend.
///
/// Decides whether the current user can perform mutating actions on this
/// task. Server is always authoritative — these flags exist purely so the
/// UI can hide/disable controls instead of letting the user tap through to
/// an `ACCESS_DENIED` response.
///
/// The full detail endpoint (`GET /api/v1/tasks/{id}`) populates every
/// field; the list endpoint (`GET /api/v1/tasks`) may or may not include
/// the object. Treat `permissions == null` as "permissive" — i.e. fall back
/// to the legacy behavior (allow) so the server is the only enforcement
/// point. The list-screen card will then react correctly the moment the
/// list endpoint adopts the field.
class TaskPermissions {
  final bool canUpdateStatus;
  final bool canUpdateProgress;
  final bool canComment;
  final bool canLogTime;
  final bool canManage;
  final bool canCreateSubtask;
  final bool canEdit;

  const TaskPermissions({
    this.canUpdateStatus = false,
    this.canUpdateProgress = false,
    this.canComment = false,
    this.canLogTime = false,
    this.canManage = false,
    this.canCreateSubtask = false,
    this.canEdit = false,
  });

  factory TaskPermissions.fromJson(Map<String, dynamic> json) {
    return TaskPermissions(
      canUpdateStatus: json['can_update_status'] as bool? ?? false,
      canUpdateProgress: json['can_update_progress'] as bool? ?? false,
      canComment: json['can_comment'] as bool? ?? false,
      canLogTime: json['can_log_time'] as bool? ?? false,
      canManage: json['can_manage'] as bool? ?? false,
      canCreateSubtask: json['can_create_subtask'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
    );
  }

  static TaskPermissions? tryFromJson(Object? raw) {
    if (raw is Map) {
      return TaskPermissions.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

/// A task as returned by GET /api/v1/tasks (list item).
///
/// As of the "flat list" backend update, [GET /api/v1/tasks] returns BOTH
/// root tasks and subtasks at any depth in a single flat list. The five
/// breadcrumb fields ([path], [pathLabel], [isSubtask], [parentId], [depth])
/// describe each task's position in the hierarchy so the card can render the
/// "Project / Parent / …" trail above the title for non-root items.
class Task {
  final int id;
  final String? code;      // TSK-001 etc.
  final String title;
  final String? description;
  final TaskProjectRef? project;
  final TaskStatusRef? status;
  final TaskPriority? priority;
  final TaskAssigneeRef? assignee;
  final String? dueDate;   // yyyy-MM-dd
  final bool isOverdue;
  final int subtasksTotal;
  final int subtasksDone;
  // ── Summary counters (optional — require backend support). ──────────
  // Each is null if the backend did not provide the field. `progress` is
  // expected as an int 0..100 computed server-side.
  final int? progress;
  final int? commentsCount;
  final int? attachmentsCount;
  final int? timeLogsCount;
  final double? timeLogsHours;
  final String? updatedAt;

  // ── Hierarchy breadcrumb (flat-list payload) ────────────────────────
  /// Titles from root to (and including) this task. Empty for legacy
  /// payloads that don't include the breadcrumb.
  final List<String> path;
  /// Pre-formatted breadcrumb, e.g. `"Finance / Stock / Products"`.
  /// The server renders this for us so we never assemble it client-side.
  final String? pathLabel;
  /// `true` when this task has a parent (i.e. depth > 0).
  final bool isSubtask;
  /// Parent task id, or `null` when this is a root task.
  final int? parentId;
  /// Depth in the hierarchy: 0 = root, 1 = direct child, 2 = grandchild, …
  final int depth;

  // ── Per-task permission flags ───────────────────────────────────────
  /// Server-decided permission flags. `null` means the endpoint did not
  /// include the object (e.g. older list payloads) — callers should treat
  /// that as "permissive" and rely on the server to enforce.
  final TaskPermissions? permissions;
  final int? companyId;
  final InlineCompanyRef? company;

  const Task({
    required this.id,
    required this.title,
    this.code,
    this.description,
    this.project,
    this.status,
    this.priority,
    this.assignee,
    this.dueDate,
    this.isOverdue = false,
    this.subtasksTotal = 0,
    this.subtasksDone = 0,
    this.progress,
    this.commentsCount,
    this.attachmentsCount,
    this.timeLogsCount,
    this.timeLogsHours,
    this.updatedAt,
    this.path = const [],
    this.pathLabel,
    this.isSubtask = false,
    this.parentId,
    this.depth = 0,
    this.permissions,
    this.companyId,
    this.company,
  });

  /// Convenience: can the current user change this task's status?
  /// Defaults to `true` when the server didn't ship a [permissions] block
  /// (legacy list payloads) so we don't break the existing UX.
  bool get canEditStatus => permissions?.canUpdateStatus ?? true;

  /// Convenience: can the current user drag this task's progress slider?
  bool get canEditProgress => permissions?.canUpdateProgress ?? true;

  /// The breadcrumb *without* the trailing task title — handy as a small
  /// gray subtitle above the title. Returns null when the task is a root
  /// (or the server didn't send a breadcrumb).
  ///
  /// Example: pathLabel "Finance / Stock / Products" → "Finance / Stock".
  String? get parentPathLabel {
    if (!isSubtask) return null;
    final label = pathLabel;
    if (label == null || label.isEmpty) return null;
    final sep = label.lastIndexOf(' / ');
    if (sep <= 0) return null;
    return label.substring(0, sep);
  }

  /// Progress percentage (0..100) for display.
  ///
  /// The backend sends `progress_percent` as an *independent* manually
  /// maintained value (NOT derived from subtasks). We return it as-is when
  /// present and clamp to 0..100 defensively. `null` means the backend
  /// omitted the field — in that (rare) case we still fall back to the
  /// subtasks ratio so older clients / legacy payloads keep showing
  /// something meaningful.
  int? get progressPercent {
    if (progress != null) return progress!.clamp(0, 100);
    if (subtasksTotal > 0) {
      return ((subtasksDone / subtasksTotal) * 100).round().clamp(0, 100);
    }
    return null;
  }

  /// Some endpoints send a nested [project] object; others only send a flat
  /// `project_id` (or `project_name`). Without this, [project] stays null and
  /// UIs that need a project id — e.g. subtask FAB + team fetch — break.
  static TaskProjectRef? _projectRefFromJson(Map<String, dynamic> json) {
    final embedded = TaskProjectRef.tryFromJson(json['project']);
    if (embedded != null && embedded.id != 0) return embedded;
    final pid = json['project_id'];
    if (pid is num && pid.toInt() != 0) {
      return TaskProjectRef(
        id: pid.toInt(),
        name: json['project_name']?.toString() ?? '',
        code: json['project_code']?.toString(),
      );
    }
    return embedded;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final pathRaw = json['path'];
    final pathList = pathRaw is List
        ? pathRaw.map((e) => e?.toString() ?? '').toList()
        : const <String>[];
    return Task(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      project: _projectRefFromJson(json),
      status: TaskStatusRef.tryFromJson(json['status']),
      priority: TaskPriority.tryFromJson(json['priority']),
      assignee: TaskAssigneeRef.tryFromJson(json['assignee']),
      dueDate: json['due_date']?.toString(),
      isOverdue: json['is_overdue'] as bool? ?? false,
      // Canonical backend field is `subtasks_count`. Legacy aliases
      // (`subtasks_total`) kept only as a defensive fallback.
      subtasksTotal: (json['subtasks_count'] as num?)?.toInt() ??
          (json['subtasks_total'] as num?)?.toInt() ??
          0,
      // Backend uses `subtasks_done_count` (based on `is_completed`, NOT
      // on status == DONE).
      subtasksDone: (json['subtasks_done_count'] as num?)?.toInt() ??
          (json['subtasks_done'] as num?)?.toInt() ??
          0,
      // `progress_percent` is a manually maintained int 0..100 on the
      // server — it is INDEPENDENT of subtasks completion.
      progress: (json['progress_percent'] as num?)?.toInt() ??
          (json['progress'] as num?)?.toInt(),
      commentsCount: (json['comments_count'] as num?)?.toInt(),
      attachmentsCount: (json['attachments_count'] as num?)?.toInt(),
      timeLogsCount: (json['time_logs_count'] as num?)?.toInt(),
      timeLogsHours: (json['time_logs_hours'] as num?)?.toDouble(),
      updatedAt: json['updated_at']?.toString(),
      // ── Hierarchy breadcrumb (flat-list payload) ──────────────────
      path: pathList,
      pathLabel: json['path_label']?.toString(),
      // Defensive: derive `is_subtask` from `parent_id`/`depth` when the
      // server didn't include the explicit flag (older endpoints).
      isSubtask: json['is_subtask'] as bool? ??
          (json['parent_id'] != null) ||
          (((json['depth'] as num?)?.toInt() ?? 0) > 0),
      parentId: (json['parent_id'] as num?)?.toInt(),
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      permissions: TaskPermissions.tryFromJson(json['permissions']),
      companyId: (json['company_id'] as num?)?.toInt() ??
          InlineCompanyRef.tryFromJson(json['company'])?.id,
      company: InlineCompanyRef.tryFromJson(json['company']),
    );
  }

  /// Returns a copy with selected fields replaced — used for optimistic
  /// updates (status change, progress drag, ...).
  Task copyWith({TaskStatusRef? status, int? progress}) {
    return Task(
      id: id,
      code: code,
      title: title,
      description: description,
      project: project,
      status: status ?? this.status,
      priority: priority,
      assignee: assignee,
      dueDate: dueDate,
      isOverdue: isOverdue,
      subtasksTotal: subtasksTotal,
      subtasksDone: subtasksDone,
      progress: progress ?? this.progress,
      commentsCount: commentsCount,
      attachmentsCount: attachmentsCount,
      timeLogsCount: timeLogsCount,
      timeLogsHours: timeLogsHours,
      updatedAt: updatedAt,
      path: path,
      pathLabel: pathLabel,
      isSubtask: isSubtask,
      parentId: parentId,
      depth: depth,
      permissions: permissions,
      companyId: companyId,
      company: company,
    );
  }
}

/// Result of `PATCH /api/v1/tasks/{id}/progress`.
///
/// When [statusChanged] is true the server auto-transitioned the task to
/// DONE (happens when progress hits 100) — callers must update the visible
/// status chip in the UI.
class TaskProgressResult {
  final int taskId;
  final int progressPercent;
  final TaskStatusRef? newStatus;
  final bool isCompleted;
  final bool statusChanged;

  const TaskProgressResult({
    required this.taskId,
    required this.progressPercent,
    required this.newStatus,
    required this.isCompleted,
    required this.statusChanged,
  });

  factory TaskProgressResult.fromJson(Map<String, dynamic> json) {
    return TaskProgressResult(
      taskId: (json['id'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      newStatus: TaskStatusRef.tryFromJson(json['status']),
      isCompleted: json['is_completed'] as bool? ?? false,
      statusChanged: json['status_changed'] as bool? ?? false,
    );
  }
}

/// Task list statistics (not affected by the status filter).
class TaskStats {
  final int total;
  final int open;
  final int done;
  final int overdue;

  const TaskStats({
    this.total = 0,
    this.open = 0,
    this.done = 0,
    this.overdue = 0,
  });

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    return TaskStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An entry in the `status_breakdown.statuses` array.
///
/// Counts are *not* affected by the `status` filter — the server keeps them
/// as-is so the user can hop between chips without losing context.
class StatusBreakdownEntry {
  final int id;
  final String code;
  final String label;
  final String color;
  final int position;
  final int count;

  const StatusBreakdownEntry({
    required this.id,
    required this.code,
    required this.label,
    required this.color,
    required this.position,
    required this.count,
  });

  factory StatusBreakdownEntry.fromJson(Map<String, dynamic> json) {
    return StatusBreakdownEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#9E9E9E',
      position: (json['position'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Dynamic status breakdown returned alongside the task list.
class StatusBreakdown {
  final int all;
  final List<StatusBreakdownEntry> statuses;

  const StatusBreakdown({this.all = 0, this.statuses = const []});

  factory StatusBreakdown.fromJson(Map<String, dynamic> json) {
    final list = (json['statuses'] as List?) ?? const [];
    final parsed = list
        .whereType<Map>()
        .map((e) => StatusBreakdownEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return StatusBreakdown(
      all: (json['all'] as num?)?.toInt() ?? 0,
      statuses: parsed,
    );
  }
}

/// Pagination metadata returned by the backend.
class PaginationInfo {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginationInfo({
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 50,
    this.total = 0,
  });

  bool get hasMore => currentPage < lastPage;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: (json['current_page'] as num?)?.toInt() ??
          (json['page'] as num?)?.toInt() ??
          1,
      lastPage: (json['last_page'] as num?)?.toInt() ??
          (json['pages'] as num?)?.toInt() ??
          1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The complete payload for GET /api/v1/tasks.
class TasksListData {
  final List<Task> tasks;
  final TaskStats stats;
  final StatusBreakdown statusBreakdown;
  final PaginationInfo pagination;

  const TasksListData({
    this.tasks = const [],
    this.stats = const TaskStats(),
    this.statusBreakdown = const StatusBreakdown(),
    this.pagination = const PaginationInfo(),
  });

  factory TasksListData.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'] ?? json['items'] ?? const [];
    final tasks = tasksRaw is List
        ? tasksRaw
            .whereType<Map>()
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Task>[];

    return TasksListData(
      tasks: tasks,
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
    );
  }
}
