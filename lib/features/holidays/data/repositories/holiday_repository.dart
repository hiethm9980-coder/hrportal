import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/holiday_models.dart';

class HolidayRepository {
  final ApiClient _client;

  HolidayRepository({required ApiClient client}) : _client = client;

  /// Fetch holidays for the employee's company.
  ///
  /// [year] defaults to the current year on the backend if not specified.
  Future<HolidaysData> getHolidays({int? year}) async {
    final response = await _client.get<HolidaysData>(
      ApiConstants.holidays,
      queryParameters: {
        'year': ?year,
      },
      fromJson: (json) => HolidaysData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
