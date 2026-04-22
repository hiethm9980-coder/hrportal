/// Request body for creating a task — used by both:
///   POST /api/v1/projects/{projectId}/tasks           (root task in project)
///   POST /api/v1/tasks/{parentTaskId}/subtasks        (subtask)
///
/// Only [title] is required by the backend; every other field is optional and
/// omitted from the JSON when null/empty so the server applies its own
/// defaults (status=TODO, priority=MEDIUM, progress=0, due_date=today,
/// assignee=creator when absent).
class CreateTaskRequest {
  final String title;
  final String? description;

  /// `LOW` | `MEDIUM` | `HIGH` | `CRITICAL`.
  final String priority;

  /// Status code from `GET /tasks/statuses` — e.g. `TODO`, `IN_PROGRESS`,
  /// `REVIEW`, `ON_HOLD`, `DONE`.
  final String? status;

  /// 0..100. Clamped by the server (422 if out of range).
  final int? progressPercent;

  /// `YYYY-MM-DD`.
  final String? dueDate;

  /// Only honored when the creator is the project manager. Silently ignored
  /// for regular members — the server forces `assignee = creator`, so the
  /// client doesn't need to send it in that case.
  final int? assigneeEmployeeId;

  /// Employee IDs of extra team members on this task. Must all be active
  /// members of the project (else 422 `VALIDATION_FAILED`).
  final List<int> members;

  const CreateTaskRequest({
    required this.title,
    this.description,
    this.priority = 'MEDIUM',
    this.status,
    this.progressPercent,
    this.dueDate,
    this.assigneeEmployeeId,
    this.members = const [],
  });

  /// [includeExplicitNullStatus]: for `POST /tasks/{id}/subtasks`, backend prefers
  /// `status` (and nullable fields) sent explicitly so defaults apply server-side.
  Map<String, dynamic> toJson({bool includeExplicitNullStatus = false}) {
    final map = <String, dynamic>{
      'title': title.trim(),
      'priority': priority,
    };
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) map['description'] = desc;
    if (includeExplicitNullStatus) {
      map['status'] = (status != null && status!.isNotEmpty) ? status : null;
    } else if (status != null && status!.isNotEmpty) {
      map['status'] = status;
    }
    if (progressPercent != null) {
      map['progress_percent'] = progressPercent!.clamp(0, 100);
    }
    if (dueDate != null && dueDate!.isNotEmpty) map['due_date'] = dueDate;
    if (assigneeEmployeeId != null) {
      map['assignee_employee_id'] = assigneeEmployeeId;
    }
    if (members.isNotEmpty) {
      // De-duplicate defensively — the backend does this too but we save a
      // round-trip when the same employee is in the checkbox list twice.
      map['members'] = members.toSet().toList();
    }
    return map;
  }
}
