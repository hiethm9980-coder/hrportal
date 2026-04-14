import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/task_models.dart';
import '../models/task_status_model.dart';

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
        if (projectId != null) 'project_id': projectId!,
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
}
