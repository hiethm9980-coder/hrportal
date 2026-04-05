import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/leave_models.dart';

/// Repository for leave endpoints.
///
/// Endpoints:
/// - GET  /leaves
/// - POST /leaves
/// - GET  /leaves/{id}
class LeaveRepository {
  final ApiClient _client;

  LeaveRepository({required ApiClient client}) : _client = client;

  Future<LeavesData> getLeaves({
    int? year,
    String? status,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<LeavesData>(
      ApiConstants.leaves,
      queryParameters: {
        'year': ?year,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => LeavesData.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }

  Future<LeaveRequest> createLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String dayPart,
    String? reason,
  }) async {
    final response = await _client.post<LeaveRequest>(
      ApiConstants.leaves,
      data: {
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'day_part': dayPart,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      fromJson: (json) => LeaveRequest.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }

  Future<LeaveRequest> getLeaveDetail(int id) async {
    final response = await _client.get<LeaveRequest>(
      ApiConstants.leaveDetail(id),
      fromJson: (json) => LeaveRequest.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }
}
