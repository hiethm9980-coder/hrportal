import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/project_brief_model.dart';

/// Lightweight project repository focused on what the "My Tasks" screen
/// needs today (list of projects for the filter dropdown).
///
/// Detail-level endpoints (/tasks, /team, /milestones, ...) will be added
/// in a dedicated projects feature module later.
class ProjectRepository {
  final ApiClient _client;

  ProjectRepository({required ApiClient client}) : _client = client;

  /// Fetch the list of projects the current user can see.
  Future<ProjectsListData> listProjects() async {
    final response = await _client.get<ProjectsListData>(
      ApiConstants.projects,
      fromJson: (json) =>
          ProjectsListData.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ProjectsListData(projects: []);
  }
}
