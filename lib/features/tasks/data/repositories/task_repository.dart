import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/comment_models.dart';
import '../models/subtasks_data.dart';
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

  /// List tasks assigned to the current user, with optional filters.
  ///
  /// - [assigneeId] defaults to `'me'` so the caller gets their own tasks.
  /// - [status] is a status *code* (e.g. `DONE`) — NOT an id.
  /// - [priority] is a priority *code* (e.g. `HIGH`).
  /// - [q] matches against title + description + code.
  Future<TasksListData> listTasks({
    String? q,
    int? projectId,
    String? status,
    String? priority,
    String? assigneeId = 'me',
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
        'project_id': ?projectId,
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
}
