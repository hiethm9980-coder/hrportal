import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

/// Repository for attendance endpoints.
///
/// Endpoints:
/// - POST /attendance/check-in
/// - POST /attendance/check-out
/// - GET  /attendance/history
class AttendanceRepository {
  final ApiClient _client;

  AttendanceRepository({required ApiClient client}) : _client = client;

  Future<AttendanceRecord> checkIn({
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final response = await _client.post<AttendanceRecord>(
      ApiConstants.checkIn,
      data: {
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      fromJson: (json) => AttendanceRecord.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }

  Future<AttendanceRecord> checkOut({
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final response = await _client.post<AttendanceRecord>(
      ApiConstants.checkOut,
      data: {
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      fromJson: (json) => AttendanceRecord.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }

  /// Attendance history.
  ///
  /// [month] format: `YYYY-MM`.
  Future<AttendanceHistoryData> getHistory({
    String? month,
    int page = 1,
    int perPage = 31,
  }) async {
    final response = await _client.get<AttendanceHistoryData>(
      ApiConstants.attendanceHistory,
      queryParameters: {
        if (month != null && month.isNotEmpty) 'month': month,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => AttendanceHistoryData.fromJson(
        json as Map<String, dynamic>,
      ),
    );
    return response.data!;
  }
}
