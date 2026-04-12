import 'package:equatable/equatable.dart';

/// A single holiday entry from GET /api/v1/holidays.
class Holiday extends Equatable {
  final int id;
  final String name;
  final String? nameEn;
  final String startDate;
  final String endDate;
  final int days;
  final bool isRecurring;
  final String? notes;

  const Holiday({
    required this.id,
    required this.name,
    this.nameEn,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.isRecurring = false,
    this.notes,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      nameEn: json['name_en'] as String?,
      startDate: (json['start_date'] as String?) ?? '',
      endDate: (json['end_date'] as String?) ?? '',
      days: (json['days'] as num?)?.toInt() ?? 1,
      isRecurring: json['is_recurring'] == true || json['is_recurring'] == 1,
      notes: json['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Parsed response from GET /api/v1/holidays.
class HolidaysData {
  final int year;
  final int total;
  final List<Holiday> holidays;

  const HolidaysData({
    required this.year,
    required this.total,
    required this.holidays,
  });

  factory HolidaysData.fromJson(Map<String, dynamic> json) {
    final list = json['holidays'] as List? ?? const [];
    return HolidaysData(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      total: (json['total'] as num?)?.toInt() ?? list.length,
      holidays: list
          .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
