import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/manager_leave_models.dart';

/// Repository for manager leave operations (approvals).
///
/// Endpoints:
/// - GET  /manager/leaves           → list pending/all leaves
/// - GET  /manager/leaves/{id}      → leave detail
/// - POST /manager/leaves/{id}/decide → approve/reject
class ManagerLeaveRepository {
  final ApiClient _client;

  ManagerLeaveRepository({required ApiClient client}) : _client = client;

  /// Fetch paginated list of leaves visible to this manager.
  Future<ManagerLeavesData> getLeaves({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final response = await _client.get<ManagerLeavesData>(
      ApiConstants.managerLeaves,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      fromJson: (json) =>
          ManagerLeavesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Submit a decision (approved/rejected) on a leave request.
  Future<void> decideLeave({
    required int id,
    required String status,
    String? rejectionReason,
  }) async {
    await _client.post<void>(
      ApiConstants.managerLeaveDecide(id),
      data: {
        'status': status,
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'rejection_reason': rejectionReason,
      },
    );
  }
}
