import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/manager_leave_models.dart';

/// Repository for manager leave operations (approvals).
///
/// Endpoints:
/// - GET  /approvals/leaves           → list pending/all leaves
/// - GET  /approvals/leaves/{id}      → leave detail
/// - POST /approvals/leaves/{id}/decide → approve/reject
class ManagerLeaveRepository {
  final ApiClient _client;

  ManagerLeaveRepository({required ApiClient client}) : _client = client;

  /// Fetch paginated list of leaves visible to this manager.
  ///
  /// [companyId] scopes the result to a single managed company; the backend
  /// uses the user's "primary" company by default when omitted (and **all
  /// companies** if `null` is passed by the caller — do not pass `0`).
  ///
  /// [filter] is one of `pending|approved|rejected|all` — backend default is
  /// `all` (returns merged history) so the "Pending" tab MUST pass `pending`
  /// explicitly to avoid mixing historical decisions in.
  Future<ManagerLeavesData> getLeaves({
    int page = 1,
    int perPage = 20,
    String? filter,
    int? companyId,
    int? isCurrent,
  }) async {
    final response = await _client.get<ManagerLeavesData>(
      ApiConstants.managerLeaves,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        'company_id': ?companyId,
        'is_current': ?isCurrent,
      },
      fromJson: (json) =>
          ManagerLeavesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Fetch full detail of a single leave request.
  Future<ManagerLeave> getLeaveDetail(int id) async {
    final response = await _client.get<ManagerLeave>(
      ApiConstants.managerLeaveDetail(id),
      fromJson: (json) {
        // The detail endpoint may wrap the leave in `{leave: {...}}` or
        // return it at the root.
        final map = json as Map<String, dynamic>;
        final leaveJson = map['leave'] is Map<String, dynamic>
            ? map['leave'] as Map<String, dynamic>
            : map;
        return ManagerLeave.fromJson(leaveJson);
      },
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
          'notes': rejectionReason,
      },
    );
  }
}
