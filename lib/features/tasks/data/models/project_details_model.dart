import 'project_brief_model.dart';

/// Per-user permission flags for a single project.
///
/// Mirrors the `permissions` block returned by
/// `GET /api/v1/hr/projects/{id}`:
///
/// ```json
/// "permissions": {
///   "can_create_task": true,
///   "can_comment":     true
/// }
/// ```
///
/// As of the backend update that tightened root-task creation, only the
/// project manager receives `can_create_task = true`. Other team members
/// still see the project but cannot add root-level tasks (they can still
/// add subtasks under tasks they own — that's gated by a different flag
/// on the task itself, `TaskDetailsPermissions.canCreateSubtask`).
///
/// Safe defaults: every flag falls back to `false` if the key is missing,
/// so we never accidentally show a privileged button to an older client
/// talking to a newer backend (or vice versa).
class ProjectPermissions {
  /// Can the current user create a root task under this project?
  /// Manager-only as of the 2026-04 backend tightening.
  final bool canCreateTask;

  /// Can the current user post project-level comments.
  final bool canComment;

  const ProjectPermissions({
    this.canCreateTask = false,
    this.canComment = false,
  });

  factory ProjectPermissions.fromJson(Map<String, dynamic> json) {
    return ProjectPermissions(
      canCreateTask: json['can_create_task'] as bool? ?? false,
      canComment: json['can_comment'] as bool? ?? false,
    );
  }

  /// Conservative fallback used when the server response omits the block
  /// entirely. Everything off — the UI hides privileged affordances and
  /// the backend still gets the final say on any attempted write.
  static const ProjectPermissions none = ProjectPermissions();
}

/// The full project detail envelope returned by
/// `GET /api/v1/hr/projects/{id}`.
///
/// We keep the project descriptor itself as a [ProjectBrief] — the list
/// and detail endpoints share the same shape there. What's new at the
/// detail level is the [permissions] block that gates per-screen UI
/// affordances (primarily the root-task FAB).
///
/// When we need more project fields later (timeline, budget summary,
/// team roster, ...), they'll be added to a dedicated class inside
/// `features/projects/`. For now this compact shape is enough to wire
/// the permission gating without dragging in the full project feature.
class ProjectDetails {
  final ProjectBrief project;
  final ProjectPermissions permissions;

  const ProjectDetails({
    required this.project,
    required this.permissions,
  });

  /// Parses the envelope's `data` object. Accepts two response shapes:
  ///
  /// 1. Nested — `{ "project": {...}, "permissions": {...} }`
  ///    (the current backend shape)
  /// 2. Flat — `{ id, name, ..., "permissions": {...} }`
  ///    (fallback for older / simpler responses)
  ///
  /// This forgiving parsing lets us survive small backend refactors
  /// without breaking the UI.
  factory ProjectDetails.fromJson(Map<String, dynamic> json) {
    final projectNode = json['project'];
    final projectJson = projectNode is Map
        ? Map<String, dynamic>.from(projectNode)
        : json;

    final permissionsNode = json['permissions'];
    final permissions = permissionsNode is Map
        ? ProjectPermissions.fromJson(Map<String, dynamic>.from(permissionsNode))
        : ProjectPermissions.none;

    return ProjectDetails(
      project: ProjectBrief.fromJson(projectJson),
      permissions: permissions,
    );
  }
}
