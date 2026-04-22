import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/activity_models.dart';
import '../models/attachment_models.dart';
import '../models/comment_models.dart';
import '../models/create_task_request.dart';
import '../models/project_team_models.dart';
import '../models/subtasks_data.dart';
import '../models/task_details_model.dart';
import '../models/task_models.dart';
import '../models/task_status_model.dart';
import '../models/time_log_models.dart';

/// Repository for task-related endpoints.
///
/// All methods return the unwrapped data payload. Errors are surfaced as
/// typed [ApiException]s by [ApiClient].
class TaskRepository {
  final ApiClient _client;

  TaskRepository({required ApiClient client}) : _client = client;

  /// Fetch the canonical list of task statuses. Should be cached by the
  /// caller — the values rarely change at runtime.
  Future<TaskStatusesData> getStatuses() async {
    final response = await _client.get<TaskStatusesData>(
      ApiConstants.taskStatuses,
      fromJson: (json) =>
          TaskStatusesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const TaskStatusesData(statuses: []);
  }

  /// List tasks visible to the current user (assignee, task member, PM, … —
  /// server rules), with optional filters.
  ///
  /// - Omit [assigneeId] (or pass null) for the default «everything relevant»
  ///   list. Pass `'me'` only when the user explicitly filters to assignee-only
  ///   (`assignee_id=me` restricts to tasks where the current user is the
  ///   assignee).
  /// - [status] is a status *code* (e.g. `DONE`) — NOT an id.
  /// - [priority] is a priority *code* (e.g. `HIGH`).
  /// - [q] matches against title + description + code.
  Future<TasksListData> listTasks({
    String? q,
    int? projectId,
    int? companyId,
    String? status,
    String? priority,
    String? assigneeId,
    bool overdue = false,
    String? dueFrom,
    String? dueTo,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<TasksListData>(
      ApiConstants.tasks,
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (projectId != null) 'project_id': projectId,
        if (companyId != null) 'company_id': companyId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
        if (overdue) 'overdue': 1,
        if (dueFrom != null && dueFrom.isNotEmpty) 'due_from': dueFrom,
        if (dueTo != null && dueTo.isNotEmpty) 'due_to': dueTo,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) =>
          TasksListData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const TasksListData();
  }

  /// Fetch a single task by id. Returns the full task payload including
  /// counters and (if the backend includes them) extended fields.
  Future<Task> getTask(int taskId) async {
    final response = await _client.get<Task>(
      ApiConstants.taskDetail(taskId),
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        // Server sometimes wraps the task under `task`, sometimes returns it
        // at the top level. Handle both.
        final taskJson = map['task'] is Map
            ? Map<String, dynamic>.from(map['task'] as Map)
            : map;
        return Task.fromJson(taskJson);
      },
    );
    return response.data ?? const Task(id: 0, title: '');
  }

  /// List subtasks of [parentTaskId] together with the parent's header
  /// payload, stats, status_breakdown and pagination.
  ///
  /// Filters mirror [listTasks] — the server combines them with AND logic.
  Future<SubtasksData> listSubtasks(
    int parentTaskId, {
    String? q,
    String? status,
    String? priority,
    String? assigneeId,
    bool overdue = false,
    String? dueFrom,
    String? dueTo,
    int? companyId,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<SubtasksData>(
      ApiConstants.taskSubtasks(parentTaskId),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
        if (overdue) 'overdue': 1,
        if (dueFrom != null && dueFrom.isNotEmpty) 'due_from': dueFrom,
        if (dueTo != null && dueTo.isNotEmpty) 'due_to': dueTo,
        if (companyId != null) 'company_id': companyId,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) =>
          SubtasksData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        SubtasksData(parent: const Task(id: 0, title: ''));
  }

  /// Update the status of a single task.
  ///
  /// [statusCode] must be a status *code* (e.g. `IN_PROGRESS`).
  Future<void> updateStatus(int taskId, String statusCode) async {
    await _client.patch<void>(
      ApiConstants.taskStatus(taskId),
      data: {'status': statusCode},
    );
  }

  /// Update only the progress percent of a task.
  ///
  /// - [percent] must be an int in 0..100 (server enforces this with 422).
  /// - When [percent] reaches 100, the server auto-transitions the task to
  ///   `DONE` and returns `status_changed: true` so the caller can refresh
  ///   the visible status chip.
  Future<TaskProgressResult> updateProgress(int taskId, int percent) async {
    final response = await _client.patch<TaskProgressResult>(
      ApiConstants.taskProgress(taskId),
      data: {'progress_percent': percent},
      fromJson: (json) =>
          TaskProgressResult.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        TaskProgressResult(
          taskId: taskId,
          progressPercent: percent,
          newStatus: null,
          isCompleted: percent >= 100,
          statusChanged: false,
        );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Time Logs
  // ═══════════════════════════════════════════════════════════════════

  /// List time logs for a task, with server-driven filtering.
  ///
  /// - [status] is one of `all` / `in_range` / `overdue` / `upcoming`.
  ///   The server always ignores the filter when computing the chip counts
  ///   themselves (so the chips never disappear).
  /// - [q] matches employee name / code / description.
  /// - [dateFrom]/[dateTo] form a window; the server returns logs whose range
  ///   intersects it.
  /// - [employeeId] is only meaningful for users allowed to view other
  ///   people's logs (project manager).
  Future<TimeLogsData> listTimeLogs(
    int taskId, {
    String? q,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? employeeId,
  }) async {
    final response = await _client.get<TimeLogsData>(
      ApiConstants.taskTimeLogs(taskId),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        if (dateFrom != null && dateFrom.isNotEmpty) 'filter_date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'filter_date_to': dateTo,
        'employee_id': ?employeeId,
      },
      fromJson: (json) =>
          TimeLogsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const TimeLogsData();
  }

  /// Create a new time log entry on [taskId].
  ///
  /// - [dateFrom] is required.
  /// - [dateTo] is optional — if omitted the server treats the log as a
  ///   single-day log (same as [dateFrom]).
  /// - [hoursSpent] must be between 0.25 and 24 (server enforces with 422).
  /// - [employeeId] is only honored for project managers; regular users can
  ///   only log time for themselves so callers should omit it.
  Future<TimeLog> createTimeLog(
    int taskId, {
    required String dateFrom,
    String? dateTo,
    required double hoursSpent,
    String? description,
    int? employeeId,
  }) async {
    final response = await _client.post<TimeLog>(
      ApiConstants.taskTimeLogs(taskId),
      data: {
        'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        'hours_spent': hoursSpent,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (employeeId != null) 'employee_id': employeeId,
      },
      fromJson: (json) => TimeLog.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        TimeLog(id: 0, rangeLabel: '', hoursSpent: hoursSpent);
  }

  /// Delete a single time log. The server enforces that only log owners and
  /// project managers can delete — we surface that via [TimeLog.canDelete] so
  /// the UI only shows the trash icon when the current user is allowed.
  Future<void> deleteTimeLog(int taskId, int logId) async {
    await _client.delete<void>(ApiConstants.taskTimeLogDelete(taskId, logId));
  }

  /// PATCH description only. [description] may be `null` to clear (server may
  /// store null). Empty string is also accepted by the API.
  Future<TimeLog> patchTimeLogDescription(
    int taskId,
    int logId, {
    required String? description,
  }) async {
    final response = await _client.patch<TimeLog>(
      ApiConstants.taskTimeLogPatch(taskId, logId),
      data: {'description': description},
      fromJson: (json) => TimeLog.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        TimeLog(id: logId, rangeLabel: '', hoursSpent: 0, description: description);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Comments + @-mentions
  // ═══════════════════════════════════════════════════════════════════

  /// List comments for a task (newest first).
  ///
  /// [q] performs a server-side full-text search over comment body + author
  /// name. Pass an empty string (or null) to fetch the full thread.
  Future<CommentsData> listComments(int taskId, {String? q}) async {
    final response = await _client.get<CommentsData>(
      ApiConstants.taskComments(taskId),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
      fromJson: (json) =>
          CommentsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const CommentsData();
  }

  /// Post a new comment.
  ///
  /// [body] should already include the `@[emp:ID|NAME]` tokens for any
  /// mentions — the server uses them to (a) extract the mentioned employee
  /// IDs and (b) push notifications to them. We never reassemble the token
  /// on the client; we always copy [MentionCandidate.mentionToken] verbatim.
  ///
  /// Returns the freshly-created comment so the UI can append it without a
  /// round-trip to GET.
  Future<Comment> createComment(int taskId, {required String body}) async {
    final response = await _client.post<Comment>(
      ApiConstants.taskComments(taskId),
      data: {'body': body},
      fromJson: (json) => Comment.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? Comment(id: 0, body: body, bodyPlain: body);
  }

  /// Delete a single comment. The server enforces that only the author can
  /// delete (returns 403 otherwise) — we mirror that with [Comment.canDelete].
  Future<void> deleteComment(int taskId, int commentId) async {
    await _client.delete<void>(
      ApiConstants.taskCommentDelete(taskId, commentId),
    );
  }

  /// Fetch the @-popup candidate list. Returns project members (priority
  /// ordered: PM → assignee → task members → project members).
  ///
  /// [q] performs a server-side filter on name / code so we don't need to
  /// load the whole list and filter on the client.
  Future<MentionCandidatesData> listMentionCandidates(
    int taskId, {
    String? q,
  }) async {
    final response = await _client.get<MentionCandidatesData>(
      ApiConstants.taskMentionCandidates(taskId),
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
      fromJson: (json) =>
          MentionCandidatesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const MentionCandidatesData();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Project team (used by the Add-Task screen)
  // ═══════════════════════════════════════════════════════════════════

  /// Fetch the full team of a project — manager + all members. Used by the
  /// Add Task screen to populate both the assignee dropdown (manager-only)
  /// and the multi-select members chip list.
  Future<ProjectTeamData> listProjectTeam(int projectId) async {
    final response = await _client.get<ProjectTeamData>(
      ApiConstants.projectTeam(projectId),
      fromJson: (json) =>
          ProjectTeamData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ProjectTeamData();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Create task / subtask
  // ═══════════════════════════════════════════════════════════════════

  /// Create a root task inside [projectId].
  ///
  /// The server enforces:
  /// - Only project members (including the manager) may call this endpoint.
  /// - [CreateTaskRequest.assigneeEmployeeId] is silently ignored when the
  ///   caller is not the project manager — the assignee becomes the creator.
  /// - Every id in [CreateTaskRequest.members] must be an active project
  ///   member, otherwise `VALIDATION_FAILED` is returned.
  ///
  /// Returns the freshly-created task so the UI can splice it into the list
  /// without a separate GET.
  Future<Task> createRootTask(
    int projectId,
    CreateTaskRequest body,
  ) async {
    final response = await _client.post<Task>(
      ApiConstants.projectTasks(projectId),
      data: body.toJson(),
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        // Server wraps the created task under `task` (canonical) but a plain
        // task payload at the top level is accepted as a defensive fallback.
        final taskJson = map['task'] is Map
            ? Map<String, dynamic>.from(map['task'] as Map)
            : map;
        return Task.fromJson(taskJson);
      },
    );
    return response.data ?? Task(id: 0, title: body.title);
  }

  /// Create a subtask under [parentTaskId]. Same fields as [createRootTask];
  /// the `parent_id` relation is implicit from the URL.
  ///
  /// Permission rules on the server: the project manager, the parent task's
  /// assignee, or a member of the parent task's team can all create subtasks.
  Future<Task> createSubtask(
    int parentTaskId,
    CreateTaskRequest body,
  ) async {
    final response = await _client.post<Task>(
      ApiConstants.taskSubtasks(parentTaskId),
      data: body.toJson(includeExplicitNullStatus: true),
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final taskJson = map['task'] is Map
            ? Map<String, dynamic>.from(map['task'] as Map)
            : map;
        return Task.fromJson(taskJson);
      },
    );
    return response.data ?? Task(id: 0, title: body.title);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Attachments
  // ═══════════════════════════════════════════════════════════════════

  /// List a task's attachments (newest first).
  ///
  /// The summary payload tells the UI whether the current user is allowed
  /// to upload new files (`can_upload`), which drives the FAB visibility.
  Future<AttachmentsData> listAttachments(int taskId) async {
    final response = await _client.get<AttachmentsData>(
      ApiConstants.taskAttachments(taskId),
      fromJson: (json) =>
          AttachmentsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const AttachmentsData();
  }

  /// Upload a single file as an attachment. The server enforces:
  /// - Max size 10 MB (422 otherwise).
  /// - Allowed extensions: pdf / webp / jpg / jpeg / png / zip.
  /// - Permission to upload (same rule as posting a comment).
  ///
  /// We build a `multipart/form-data` body ourselves because the generic
  /// `ApiClient.post` accepts arbitrary `data` — we pass Dio's `FormData`
  /// which transparently triggers multipart.
  Future<TaskAttachment> uploadAttachment(
    int taskId, {
    required String filePath,
    String? filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final response = await _client.post<TaskAttachment>(
      ApiConstants.taskAttachments(taskId),
      data: form,
      fromJson: (json) =>
          TaskAttachment.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        const TaskAttachment(id: 0, name: '');
  }

  /// Delete a single attachment. Server enforces that only the uploader
  /// (or roles with broader permission) can delete — the UI guards this
  /// with [TaskAttachment.canDelete] but the server is authoritative.
  Future<void> deleteAttachment(int taskId, int attachmentId) async {
    await _client.delete<void>(
      ApiConstants.taskAttachmentDelete(taskId, attachmentId),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Activity
  // ═══════════════════════════════════════════════════════════════════

  /// Unified activity feed: status-change events + audit-log entries
  /// (comments, attachments, time logs, subtasks, …) in one sorted list.
  /// Items come newest-first from the server; UI does not need to re-sort.
  Future<ActivityData> listActivity(int taskId) async {
    final response = await _client.get<ActivityData>(
      ApiConstants.taskActivity(taskId),
      fromJson: (json) => ActivityData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ActivityData();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Task details (full payload + edit + delete)
  // ═══════════════════════════════════════════════════════════════════

  /// Full task detail including path / project / team / counts /
  /// audit info, plus a fine-grained `permissions` block that drives
  /// which edit controls the UI renders.
  Future<TaskDetails> getTaskDetails(int taskId) async {
    final response = await _client.get<TaskDetails>(
      ApiConstants.taskDetail(taskId),
      fromJson: (json) => TaskDetails.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        const TaskDetails(id: 0, title: '');
  }

  /// Partially update a task. Only include keys you want to change —
  /// unset keys are left untouched on the server. Returns the *full*
  /// post-update [TaskDetails] so the UI can refresh in one round-trip.
  ///
  /// Accepted keys (all optional):
  ///   title, description, priority, status, progress_percent, due_date,
  ///   assignee_employee_id, members (List&lt;int&gt;)
  Future<TaskDetails> patchTaskDetails(
    int taskId,
    Map<String, dynamic> changes,
  ) async {
    final response = await _client.patch<TaskDetails>(
      ApiConstants.taskDetail(taskId),
      data: changes,
      fromJson: (json) => TaskDetails.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        const TaskDetails(id: 0, title: '');
  }

  /// Soft-delete a task. Server returns 200 on success, 403 if the
  /// caller isn't the project manager.
  Future<void> deleteTask(int taskId) async {
    await _client.delete<void>(ApiConstants.taskDetail(taskId));
  }
}
