/// `GET /api/v1/projects/{id}/member-candidates` (project manager only).

class ProjectMemberCandidate {
  final int id;
  final String code;
  final String name;
  final bool isInProject;
  final bool isProjectManager;

  const ProjectMemberCandidate({
    required this.id,
    required this.code,
    required this.name,
    this.isInProject = false,
    this.isProjectManager = false,
  });

  factory ProjectMemberCandidate.fromJson(Map<String, dynamic> json) {
    // Flat shape or nested `employee` (common in API envelopes).
    final emp = json['employee'];
    final empMap = emp is Map ? Map<String, dynamic>.from(emp) : null;
    int id = (json['id'] as num?)?.toInt() ??
        (json['employee_id'] as num?)?.toInt() ?? 0;
    if (id == 0 && empMap != null) {
      id = (empMap['id'] as num?)?.toInt() ?? 0;
    }
    var code = json['code']?.toString() ?? '';
    var name = json['name']?.toString() ?? '';
    if (code.isEmpty && empMap != null) {
      code = empMap['code']?.toString() ?? '';
    }
    if (name.isEmpty && empMap != null) {
      name = empMap['name']?.toString() ?? '';
    }
    return ProjectMemberCandidate(
      id: id,
      code: code,
      name: name,
      isInProject: _asBool(json['is_in_project']),
      isProjectManager: _asBool(json['is_project_manager']),
    );
  }
}

bool _asBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

class ProjectMemberCandidatesData {
  final List<ProjectMemberCandidate> candidates;

  const ProjectMemberCandidatesData({required this.candidates});

  /// Accepts [data] as a list, or a map with `candidates` / `items` / `employees` / `data` (list or nested map).
  factory ProjectMemberCandidatesData.fromDataJson(Object? data) {
    if (data is List) {
      return ProjectMemberCandidatesData(
        candidates: data
            .map(
              (e) => ProjectMemberCandidate.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
    }
    if (data is! Map) {
      return const ProjectMemberCandidatesData(candidates: []);
    }
    final m = Map<String, dynamic>.from(data);
    List<dynamic> list = m['candidates'] as List? ??
        m['items'] as List? ??
        m['employees'] as List? ??
        m['data'] as List? ??
        const [];
    if (list.isEmpty && m['data'] is Map) {
      final inner = Map<String, dynamic>.from(m['data'] as Map);
      list = inner['candidates'] as List? ?? const [];
    }
    return ProjectMemberCandidatesData(
      candidates: list
          .map(
            (e) => ProjectMemberCandidate.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}
