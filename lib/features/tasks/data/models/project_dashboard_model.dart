// Models for GET /api/v1/projects/{id}/dashboard (project KPI dashboard).

class ProjectDashboardData {
  final ProjectDashboardProject project;
  final ProjectDashboardCounts counts;
  final List<TaskStatusCountRow> tasksByStatus;
  final ProjectDashboardTeam team;

  const ProjectDashboardData({
    required this.project,
    required this.counts,
    required this.tasksByStatus,
    required this.team,
  });

  factory ProjectDashboardData.fromJson(Map<String, dynamic> json) {
    return ProjectDashboardData(
      project: ProjectDashboardProject.fromJson(
        Map<String, dynamic>.from(json['project'] as Map? ?? {}),
      ),
      counts: ProjectDashboardCounts.fromJson(
        Map<String, dynamic>.from(json['counts'] as Map? ?? {}),
      ),
      tasksByStatus: (json['tasks_by_status'] as List?)
              ?.map((e) => TaskStatusCountRow.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const [],
      team: ProjectDashboardTeam.fromJson(
        Map<String, dynamic>.from(json['team'] as Map? ?? {}),
      ),
    );
  }
}

class DashboardEmployeeRef {
  final int id;
  final String code;
  final String name;

  const DashboardEmployeeRef({
    required this.id,
    required this.code,
    required this.name,
  });

  factory DashboardEmployeeRef.fromJson(Map<String, dynamic> json) {
    return DashboardEmployeeRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class LabelledCodeColor {
  final String code;
  final String label;
  final String? color;

  const LabelledCodeColor({
    required this.code,
    required this.label,
    this.color,
  });

  factory LabelledCodeColor.fromJson(Map<String, dynamic> json) {
    return LabelledCodeColor(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }
}

class ProjectDashboardProject {
  final int id;
  final String code;
  final String name;
  final String? description;
  final LabelledCodeColor status;
  final LabelledCodeColor? priority;
  final int progressPercent;
  final String? startDate;
  final String? endDate;
  final bool isOverdue;
  final DashboardEmployeeRef manager;

  const ProjectDashboardProject({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.status,
    this.priority,
    required this.progressPercent,
    this.startDate,
    this.endDate,
    required this.isOverdue,
    required this.manager,
  });

  factory ProjectDashboardProject.fromJson(Map<String, dynamic> json) {
    final pri = json['priority'];
    return ProjectDashboardProject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      status: LabelledCodeColor.fromJson(
        Map<String, dynamic>.from(json['status'] as Map? ?? {}),
      ),
      priority: pri is Map
          ? LabelledCodeColor.fromJson(Map<String, dynamic>.from(pri))
          : null,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      isOverdue: json['is_overdue'] as bool? ?? false,
      manager: DashboardEmployeeRef.fromJson(
        Map<String, dynamic>.from(json['manager'] as Map? ?? {}),
      ),
    );
  }
}

class ProjectDashboardCounts {
  final int tasksTotal;
  final int tasksRoot;
  final int tasksSubtask;
  final int tasksUnassigned;

  const ProjectDashboardCounts({
    required this.tasksTotal,
    required this.tasksRoot,
    required this.tasksSubtask,
    required this.tasksUnassigned,
  });

  factory ProjectDashboardCounts.fromJson(Map<String, dynamic> json) {
    return ProjectDashboardCounts(
      tasksTotal: (json['tasks_total'] as num?)?.toInt() ?? 0,
      tasksRoot: (json['tasks_root'] as num?)?.toInt() ?? 0,
      tasksSubtask: (json['tasks_subtask'] as num?)?.toInt() ?? 0,
      tasksUnassigned: (json['tasks_unassigned'] as num?)?.toInt() ?? 0,
    );
  }
}

class TaskStatusCountRow {
  final LabelledCodeColor status;
  final int count;

  const TaskStatusCountRow({
    required this.status,
    required this.count,
  });

  factory TaskStatusCountRow.fromJson(Map<String, dynamic> json) {
    return TaskStatusCountRow(
      status: LabelledCodeColor.fromJson(
        Map<String, dynamic>.from(json['status'] as Map? ?? {}),
      ),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProjectDashboardTeam {
  final int membersCount;
  final DashboardEmployeeRef manager;
  final List<TeamMemberDashboard> members;

  const ProjectDashboardTeam({
    required this.membersCount,
    required this.manager,
    required this.members,
  });

  factory ProjectDashboardTeam.fromJson(Map<String, dynamic> json) {
    return ProjectDashboardTeam(
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      manager: DashboardEmployeeRef.fromJson(
        Map<String, dynamic>.from(json['manager'] as Map? ?? {}),
      ),
      members: (json['members'] as List?)
              ?.map((e) => TeamMemberDashboard.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const [],
    );
  }
}

class TeamMemberDashboard {
  final DashboardEmployeeRef employee;
  final String roleCode;
  final String roleLabel;
  final bool isManagerRole;
  final int tasksAssignedTotal;
  final List<TaskStatusCountRow> tasksByStatus;

  const TeamMemberDashboard({
    required this.employee,
    required this.roleCode,
    required this.roleLabel,
    required this.isManagerRole,
    required this.tasksAssignedTotal,
    required this.tasksByStatus,
  });

  factory TeamMemberDashboard.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    return TeamMemberDashboard(
      employee: DashboardEmployeeRef.fromJson(
        Map<String, dynamic>.from(emp is Map ? emp : {}),
      ),
      roleCode: json['role_code']?.toString() ?? '',
      roleLabel: json['role_label']?.toString() ?? '',
      isManagerRole: json['is_manager_role'] as bool? ?? false,
      tasksAssignedTotal:
          (json['tasks_assigned_total'] as num?)?.toInt() ?? 0,
      tasksByStatus: (json['tasks_by_status'] as List?)
              ?.map((e) => TaskStatusCountRow.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const [],
    );
  }
}
