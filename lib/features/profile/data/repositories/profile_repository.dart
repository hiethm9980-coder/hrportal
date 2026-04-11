import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/auth_models.dart';
import '../models/employee_profile_model.dart';

/// Repository for employee profile endpoints.
///
/// Endpoints:
/// - GET  /auth/me            (read — richer payload than /employee/profile)
/// - PUT  /employee/profile   (write — partial update)
class ProfileRepository {
  final ApiClient _client;

  ProfileRepository({required ApiClient client}) : _client = client;

  /// Fetch the current employee's profile via `/auth/me`.
  ///
  /// We deliberately use `/auth/me` instead of `/employee/profile` because the
  /// former returns a richer payload (department, branch, manager, company
  /// codes, approval flags, …) and is the canonical "current user" endpoint.
  Future<EmployeeProfile> getProfile() async {
    final response = await _client.get<CurrentUserData>(
      ApiConstants.me,
      fromJson: (json) =>
          CurrentUserData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!.employee;
  }

  /// Update profile fields.
  ///
  /// The contract may allow partial updates. Provide fields in [data].
  Future<EmployeeProfile> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.put<EmployeeProfile>(
      ApiConstants.profile,
      data: data,
      fromJson: (json) => EmployeeProfile.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }
}
