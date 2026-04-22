import 'package:dio/dio.dart' show FormData, MultipartFile;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/project_brief_model.dart';
import '../models/project_dashboard_model.dart';
import '../models/project_details_model.dart';
import '../models/project_document_models.dart';
import '../models/project_member_models.dart';

/// Lightweight project repository focused on what the "My Tasks" screen
/// needs today (list of projects for the filter dropdown + per-project
/// permission lookup for the Add Task FAB).
///
/// Detail-level endpoints (/tasks, /team, /milestones, ...) will be added
/// in a dedicated projects feature module later.
class ProjectRepository {
  final ApiClient _client;

  ProjectRepository({required ApiClient client}) : _client = client;

  /// Fetch the list of projects the current user can see.
  ///
  /// [companyId]: omit for API default scope; or one allowed company id.
  Future<ProjectsListData> listProjects({int? companyId}) async {
    final response = await _client.get<ProjectsListData>(
      ApiConstants.projects,
      queryParameters: {
        if (companyId != null) 'company_id': companyId,
      },
      fromJson: (json) =>
          ProjectsListData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ProjectsListData(projects: []);
  }

  /// Fetch a single project's details along with the per-user permission
  /// block. Used primarily to decide whether to show the "Add root task"
  /// FAB (`permissions.can_create_task`) — as of 2026-04 that flag is
  /// granted only to the project manager.
  ///
  /// Returns a forgiving fallback (permissions all-off) if the payload
  /// turns out to be empty, so the UI never crashes and simply hides
  /// privileged affordances.
  Future<ProjectDetails> getProjectDetails(int projectId) async {
    final response = await _client.get<ProjectDetails>(
      ApiConstants.projectDetail(projectId),
      fromJson: (json) => ProjectDetails.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        ProjectDetails(
          project: ProjectBrief(id: projectId, name: ''),
          permissions: ProjectPermissions.none,
        );
  }

  /// KPI dashboard for a project (`GET .../projects/{id}/dashboard`).
  Future<ProjectDashboardData> getProjectDashboard(int projectId) async {
    final response = await _client.get<ProjectDashboardData>(
      ApiConstants.projectDashboard(projectId),
      fromJson: (json) =>
          ProjectDashboardData.fromJson(json as Map<String, dynamic>),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Empty project dashboard payload');
    }
    return data;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Project documents (`GET/POST/DELETE .../projects/{id}/documents`)
  // ═══════════════════════════════════════════════════════════════════

  /// Newest first (server order). Summary drives FAB / empty-state affordances.
  Future<ProjectDocumentsData> listProjectDocuments(int projectId) async {
    final response = await _client.get<ProjectDocumentsData>(
      ApiConstants.projectDocuments(projectId),
      fromJson: (json) =>
          ProjectDocumentsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ProjectDocumentsData();
  }

  /// Uploads a file (project manager; server enforces rules).
  ///
  /// [description] is optional, sent as a separate form field (Laravel
  /// contract: `file` + `description?`).
  Future<ProjectDocumentItem> uploadProjectDocument(
    int projectId, {
    required String filePath,
    String? filename,
    String? description,
  }) async {
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    };
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      map['description'] = desc;
    }
    final form = FormData.fromMap(map);
    final response = await _client.post<ProjectDocumentItem>(
      ApiConstants.projectDocuments(projectId),
      data: form,
      fromJson: (json) {
        return projectDocumentFromMutationResponse(json) ??
            ProjectDocumentItem(id: 0, name: filename ?? 'file');
      },
    );
    return response.data ??
        ProjectDocumentItem(id: 0, name: filename ?? 'file');
  }

  Future<void> deleteProjectDocument(int projectId, int documentId) async {
    await _client.delete<void>(
      ApiConstants.projectDocumentDelete(projectId, documentId),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Project update + team (project manager)
  // ═══════════════════════════════════════════════════════════════════

  /// Partial update — `name`, `description`, `status`, `priority`,
  /// `progress_percent`, `start_date`, `end_date` (Y-m-d where applicable).
  Future<void> updateProject(int projectId, Map<String, dynamic> data) async {
    await _client.patch<void>(
      ApiConstants.projectDetail(projectId),
      data: data,
    );
  }

  Future<ProjectMemberCandidatesData> getProjectMemberCandidates(
    int projectId, {
    String? q,
  }) async {
    final response = await _client.get<ProjectMemberCandidatesData>(
      ApiConstants.projectMemberCandidates(projectId),
      queryParameters: {if (q != null && q.trim().isNotEmpty) 'q': q.trim()},
      fromJson: (json) => ProjectMemberCandidatesData.fromDataJson(json),
    );
    return response.data ?? const ProjectMemberCandidatesData(candidates: []);
  }

  Future<void> addProjectMembers(int projectId, List<int> employeeIds) async {
    if (employeeIds.isEmpty) return;
    // Backend (per contract) may read `employee_ids` or `members` as id[]; send
    // both to avoid 422 when the controller only binds one of them.
    await _client.post<void>(
      ApiConstants.projectMembers(projectId),
      data: {
        'employee_ids': employeeIds,
        'members': employeeIds,
      },
    );
  }

  Future<void> removeProjectMember(int projectId, int employeeId) async {
    await _client.delete<void>(
      ApiConstants.projectMember(projectId, employeeId),
    );
  }
}
