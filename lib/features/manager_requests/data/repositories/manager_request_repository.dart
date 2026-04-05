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

  /// Fetch paginated list of requests visible to this manager.
  Future<ManagerRequestsData> getRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    String? requestType,
    int? employeeId,
  }) async {
    final response = await _client.get<ManagerRequestsData>(
      ApiConstants.managerRequests,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (requestType != null && requestType.isNotEmpty)
          'request_type': requestType,
        'employee_id': ?employeeId,
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
      fromJson: (json) =>
          ManagerRequestDetail.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Submit a decision (approve/reject/processing/completed) on a request.
  Future<ManagerRequest> decideRequest({
    required int id,
    required String status,
    String? responseNotes,
  }) async {
    final response = await _client.post<ManagerRequest>(
      ApiConstants.managerRequestDecide(id),
      data: {
        'status': status,
        if (responseNotes != null && responseNotes.isNotEmpty)
          'response_notes': responseNotes,
      },
      fromJson: (json) =>
          ManagerRequest.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
