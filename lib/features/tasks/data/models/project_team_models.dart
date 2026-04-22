/// Models for `GET /api/v1/projects/{id}/team`.
///
/// The team endpoint returns every employee who may be referenced on a task
/// inside this project — i.e. the project manager plus all project members.
/// The UI uses it for:
///   - the "members" checkbox chip picker on the Add Task screen,
///   - the "assignee" dropdown shown to project managers only,
///   - determining whether the current user is the project manager (via
///     [ProjectTeamData.managerId]) so we know whether to lock the assignee
///     field to the creator.
library;

/// Role of a team entry. The backend sends these codes verbatim — we keep
/// them as strings so new roles don't require a model change.
class ProjectTeamRole {
  static const String manager = 'MANAGER';
  static const String member = 'MEMBER';
  ProjectTeamRole._();
}

/// One person inside the project team.
class ProjectTeamMember {
  final int id;
  final String? code;
  final String name;
  final String? photoUrl;

  /// `MANAGER` | `MEMBER` (see [ProjectTeamRole]). Empty string if the
  /// server didn't include the field (defensive).
  final String role;

  /// Optional job title — shown as a secondary line under the name when the
  /// backend provides it.
  final String? jobTitle;

  const ProjectTeamMember({
    required this.id,
    required this.name,
    this.code,
    this.photoUrl,
    this.role = '',
    this.jobTitle,
  });

  bool get isManager => role == ProjectTeamRole.manager;

  /// Parse a single team row. Handles three common backend shapes:
  ///   1. Flat:      `{id, name, code, role, ...}`
  ///   2. Wrapped:   `{employee: {id, name, code, ...}, role: "MANAGER"}`
  ///   3. Prefixed:  `{employee_id, employee_name, employee_code, role}`
  ///
  /// If [defaultRole] is provided we use it when the entry has no explicit
  /// `role` field — used when the backend returns a separate `manager`
  /// object (tag it as MANAGER) vs the `members` array (tag as MEMBER).
  factory ProjectTeamMember.fromJson(
    Map<String, dynamic> json, {
    String? defaultRole,
  }) {
    // Shape #2: nested employee object.
    final nestedRaw = json['employee'] ?? json['user'] ?? json['member'];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};

    int parseId() {
      final v = json['id'] ??
          nested['id'] ??
          json['employee_id'] ??
          json['user_id'];
      return (v as num?)?.toInt() ?? 0;
    }

    String parseName() {
      final v = json['name'] ??
          nested['name'] ??
          json['employee_name'] ??
          json['full_name'] ??
          json['display_name'];
      return v?.toString() ?? '';
    }

    String? parseCode() {
      final v = json['code'] ??
          nested['code'] ??
          json['employee_code'];
      return v?.toString();
    }

    String? parsePhoto() {
      final v = json['photo_url'] ??
          json['avatar'] ??
          json['avatar_url'] ??
          nested['photo_url'] ??
          nested['avatar'] ??
          nested['avatar_url'];
      return v?.toString();
    }

    /// Detect the manager flag across all shapes the backend has used so far:
    ///   - `is_manager_role: true`       (canonical)
    ///   - `role_code: "MANAGER"`        (preferred string form)
    ///   - `role: "MANAGER"`             (legacy)
    /// Comparison is case-insensitive because the dev server occasionally
    /// returns `"manager"` lowercase.
    String parseRole() {
      final isManagerFlag = json['is_manager_role'] as bool? ?? false;
      if (isManagerFlag) return ProjectTeamRole.manager;

      final raw = (json['role_code'] ?? json['role'])?.toString();
      if (raw != null && raw.toUpperCase() == ProjectTeamRole.manager) {
        return ProjectTeamRole.manager;
      }
      if (raw != null && raw.isNotEmpty) return raw.toUpperCase();
      return defaultRole ?? '';
    }

    return ProjectTeamMember(
      id: parseId(),
      name: parseName(),
      code: parseCode(),
      photoUrl: parsePhoto(),
      role: parseRole(),
      jobTitle: json['job_title']?.toString() ??
          json['position']?.toString() ??
          nested['job_title']?.toString() ??
          nested['position']?.toString(),
    );
  }
}

/// Flat payload of the team endpoint. We precompute [managerId] so callers
/// can decide whether the current user is the PM in O(1).
class ProjectTeamData {
  final List<ProjectTeamMember> members;

  const ProjectTeamData({this.members = const []});

  int? get managerId {
    for (final m in members) {
      if (m.isManager) return m.id;
    }
    return null;
  }

  /// Only the non-manager members — handy when you want to list "project
  /// members" separately from the manager in the UI.
  List<ProjectTeamMember> get regularMembers =>
      members.where((m) => !m.isManager).toList();

  factory ProjectTeamData.fromJson(Map<String, dynamic> json) {
    final list = <ProjectTeamMember>[];

    // Shape A: dedicated `manager` object + `members[]` array.
    final managerRaw = json['manager'] ?? json['project_manager'];
    if (managerRaw is Map) {
      list.add(ProjectTeamMember.fromJson(
        Map<String, dynamic>.from(managerRaw),
        defaultRole: ProjectTeamRole.manager,
      ));
    }

    // Shape B / C: single array under any of these keys.
    //   `team` (canonical), `members`, `items`, `employees`, `data`.
    final arrayRaw = json['team'] ??
        json['members'] ??
        json['items'] ??
        json['employees'] ??
        json['data'];
    if (arrayRaw is List) {
      for (final e in arrayRaw) {
        if (e is Map) {
          list.add(ProjectTeamMember.fromJson(
            Map<String, dynamic>.from(e),
            // When the array coexists with a `manager` key we default any
            // entry without an explicit role to MEMBER so the UI doesn't
            // label every unrolled row as MANAGER.
            defaultRole: managerRaw is Map ? ProjectTeamRole.member : null,
          ));
        }
      }
    }

    // Defensive de-dup by id — if the backend lists someone as both "member"
    // and "manager" we keep the manager entry (priority: MANAGER > MEMBER).
    // Rows with id=0 are filtered out (malformed payload → don't let them
    // collapse every other member into a single "?" chip).
    final byId = <int, ProjectTeamMember>{};
    for (final m in list) {
      if (m.id == 0) continue;
      final existing = byId[m.id];
      if (existing == null || (m.isManager && !existing.isManager)) {
        byId[m.id] = m;
      }
    }
    return ProjectTeamData(members: byId.values.toList());
  }
}
