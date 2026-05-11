/// Models for `POST /tasks/{id}/subtasks/ai-bulk` — generates multiple
/// subtasks at once via the backend's AI assistant.
///
/// We deliberately keep the response model lean: the screen only needs the
/// created count and the post-call rate-limit window. The freshly-created
/// subtasks are pulled by the regular subtasks list refresh — re-parsing
/// them here would just duplicate [Task.fromJson] for no gain.
/// Distribution mode for the generated subtasks' due dates.
///
/// - [sequential] — every task gets its own day, starting from
///   `due_date_start` and incrementing by +1 day per task.
/// - [fixed] — every task shares the same date (`due_date_start`).
enum AiBulkDueDateMode {
  sequential('sequential'),
  fixed('fixed');

  const AiBulkDueDateMode(this.code);
  final String code;
}

class AiBulkSubtasksRequest {
  /// Free-text job title of the current user. Used as AI context only.
  final String employeeJob;

  /// Title of the parent task — context for the AI prompt.
  final String parentTask;

  /// Subtasks separated by `;`. Server cleans empties / collapses `;;`.
  /// Hard cap of 10 entries enforced server-side (422 otherwise).
  final String taskText;

  /// Optional `0..100` progress applied to every generated subtask. The
  /// server derives the matching status from the value (`100 → DONE`,
  /// `1..99 → IN_PROGRESS`, `0 → TODO`). Omit (`null`) to fall back to
  /// the server default of 0 / TODO.
  final int? defaultProgress;

  /// Optional `YYYY-MM-DD` start date. When omitted the server defaults
  /// to **tomorrow**.
  final String? dueDateStart;

  /// Optional spread mode — see [AiBulkDueDateMode]. Omit to use the
  /// server default (`sequential`).
  final AiBulkDueDateMode? dueDateMode;

  const AiBulkSubtasksRequest({
    required this.employeeJob,
    required this.parentTask,
    required this.taskText,
    this.defaultProgress,
    this.dueDateStart,
    this.dueDateMode,
  });

  Map<String, dynamic> toJson() => {
        'employee_job': employeeJob,
        'parent_task': parentTask,
        'task_text': taskText,
        if (defaultProgress != null) 'default_progress': defaultProgress,
        if (dueDateStart != null && dueDateStart!.isNotEmpty)
          'due_date_start': dueDateStart,
        if (dueDateMode != null) 'due_date_mode': dueDateMode!.code,
      };
}

/// Slim response — only the bits the UI shows to the user.
class AiBulkSubtasksResult {
  /// How many subtasks were ultimately created (server backfills if AI
  /// returned fewer than requested, so this matches `input_count`).
  final int createdCount;

  /// Remaining attempts in the current rate-limit window.
  final int rateLimitRemaining;

  /// Total attempts allowed per window.
  final int rateLimitTotal;

  /// Seconds until the window resets — useful when remaining hits 0.
  final int rateLimitResetInSeconds;

  const AiBulkSubtasksResult({
    required this.createdCount,
    required this.rateLimitRemaining,
    required this.rateLimitTotal,
    required this.rateLimitResetInSeconds,
  });

  factory AiBulkSubtasksResult.fromJson(Map<String, dynamic> data) {
    final aiMeta = data['ai_meta'] is Map
        ? Map<String, dynamic>.from(data['ai_meta'] as Map)
        : const <String, dynamic>{};
    final rl = data['rate_limit'] is Map
        ? Map<String, dynamic>.from(data['rate_limit'] as Map)
        : const <String, dynamic>{};
    final subtasks = data['subtasks'];
    final fromList = subtasks is List ? subtasks.length : 0;
    final createdMeta = (aiMeta['created_count'] as num?)?.toInt();
    return AiBulkSubtasksResult(
      // Prefer the explicit AI meta count; fall back to the array length.
      createdCount: createdMeta ?? fromList,
      rateLimitRemaining: (rl['remaining'] as num?)?.toInt() ?? 0,
      rateLimitTotal: (rl['limit'] as num?)?.toInt() ?? 0,
      rateLimitResetInSeconds: (rl['reset_in_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
