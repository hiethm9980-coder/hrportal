import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/leave_models.dart';

class LeaveRepository {
  final ApiClient _client;

  LeaveRepository({required ApiClient client}) : _client = client;

  Future<LeavesData> getLeaves({
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<LeavesData>(
      ApiConstants.leaveRequests,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => LeavesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Get leave balances for the current employee.
  Future<LeaveBalancesData> getBalances({int? year}) async {
    final response = await _client.get<LeaveBalancesData>(
      ApiConstants.leaveBalances,
      queryParameters: {
        if (year != null) 'year': year,
      },
      fromJson: (json) => LeaveBalancesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Get leave requests summary (counts per status).
  Future<LeaveSummary> getSummary() async {
    final response = await _client.get<LeaveSummary>(
      ApiConstants.leaveRequestsSummary,
      fromJson: (json) => LeaveSummary.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Create a leave request.
  /// [action] can be 'draft' (save) or 'submit' (send for approval).
  Future<LeaveRequest> createLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String action,
    String? reason,
  }) async {
    final response = await _client.post<LeaveRequest>(
      ApiConstants.leaveRequests,
      data: {
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      fromJson: (json) => LeaveRequest.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Submit a draft leave request for approval.
  Future<void> submitLeave(int id) async {
    await _client.post<void>(ApiConstants.leaveRequestSubmit(id));
  }

  /// Delete a leave request (draft or pending only).
  Future<void> deleteLeave(int id) async {
    await _client.delete<void>(ApiConstants.leaveRequestDelete(id));
  }
}
