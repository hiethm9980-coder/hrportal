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
  /// Filters (all optional, combined with AND on the backend):
  /// - [month]: `YYYY-MM`. Used when no [dateFrom]/[dateTo] are passed.
  /// - [dateFrom] + [dateTo]: `YYYY-MM-DD` — custom range. Both required
  ///   together; when present they override [month].
  /// - [statuses]: one or more status codes from the allowed set:
  ///   `pending` · `present` · `late` · `early_departure` · `late_and_early`
  ///   · `shortage` · `absent` · `incomplete` · `weekend` · `holiday`
  ///   · `on_leave`. Sent as a comma-separated list to the backend.
  ///
  /// Important note about `summary`: the backend response keeps `summary`
  /// reflecting the full date period (NOT affected by status filter) — only
  /// `records` and `pagination.total` are narrowed. The chip counts stay
  /// stable even after selecting a single-status pill.
  Future<AttendanceHistoryData> getHistory({
    String? month,
    String? dateFrom,
    String? dateTo,
    List<String>? statuses,
    int page = 1,
    int perPage = 31,
  }) async {
    final response = await _client.get<AttendanceHistoryData>(
      ApiConstants.attendanceHistory,
      queryParameters: {
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        // Only send `month` when no explicit range — backend prefers range.
        if ((dateFrom == null || dateFrom.isEmpty) &&
            (dateTo == null || dateTo.isEmpty) &&
            month != null &&
            month.isNotEmpty)
          'month': month,
        if (statuses != null && statuses.isNotEmpty)
          'status': statuses.join(','),
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
