import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/manager_request_models.dart';

/// Repository for manager request operations (approvals).
///
/// Endpoints:
/// - GET  /manager/requests           → list pending/all requests
/// - GET  /manager/requests/{id}      → request detail
/// - POST /manager/requests/{id}/decide → approve/reject/process
class ManagerRequestRepository {
  final ApiClient _client;

  ManagerRequestRepository({required ApiClient client}) : _client = client;

  /// Fetch paginated list of (other) requests visible to this manager.
  ///
  /// [filter] is one of `pending|approved|rejected|all` — backend default is
  /// `all` (merged history). The "Pending" tab MUST pass `pending` explicitly.
  /// [companyId] is omitted entirely for the "All companies" option (do not
  /// send `0` — the backend rejects it with 422).
  Future<ManagerRequestsData> getRequests({
    int page = 1,
    int perPage = 20,
    String? filter,
    String? requestType,
    int? employeeId,
    int? companyId,
    int? isCurrent,
  }) async {
    final response = await _client.get<ManagerRequestsData>(
      ApiConstants.managerRequests,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        if (requestType != null && requestType.isNotEmpty)
          'request_type': requestType,
        if (employeeId != null) 'employee_id': employeeId,
        if (companyId != null) 'company_id': companyId,
        if (isCurrent != null) 'is_current': isCurrent,
      },
      fromJson: (json) =>
          ManagerRequestsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Fetch full detail of a single request.
  Future<ManagerRequestDetail> getRequestDetail(int id) async {
    final response = await _client.get<ManagerRequestDetail>(
      ApiConstants.managerRequestDetail(id),
      fromJson: (json) {
        final map = json as Map<String, dynamic>;
        final reqJson = map['request'] is Map<String, dynamic>
            ? map['request'] as Map<String, dynamic>
            : map;
        return ManagerRequestDetail.fromJson(reqJson);
      },
    );
    return response.data!;
  }

  /// Submit a decision on a request.
  ///
  /// Unlike leaves, the backend exposes **separate** `/approve` and `/reject`
  /// endpoints for employee requests — there is no `/decide` alias here. This
  /// method routes to the right URL based on [status].
  Future<void> decideRequest({
    required int id,
    required String status,
    String? responseNotes,
  }) async {
    final url = status == 'rejected'
        ? ApiConstants.managerRequestReject(id)
        : ApiConstants.managerRequestApprove(id);

    await _client.post<void>(
      url,
      data: {
        if (responseNotes != null && responseNotes.isNotEmpty)
          'response_notes': responseNotes,
      },
    );
  }
}
