/// Model for a single booked day from the API.
///
/// Each day has a date, day_part (full/first_half/second_half),
/// and the associated leave request status (pending/approved).
class BookedDay {
  final String date;
  final String dayPart; // full, first_half, second_half
  final double dayValue; // 1.0 or 0.5
  final String status; // pending, approved
  final String? requestNumber;
  final String? leaveTypeName;
  final String? leaveTypeColor;

  const BookedDay({
    required this.date,
    required this.dayPart,
    required this.dayValue,
    required this.status,
    this.requestNumber,
    this.leaveTypeName,
    this.leaveTypeColor,
  });

  factory BookedDay.fromJson(Map<String, dynamic> json) {
    final leaveRequest = json['leave_request'] as Map<String, dynamic>? ?? {};
    final leaveType = json['leave_type'] as Map<String, dynamic>? ?? {};

    return BookedDay(
      date: json['date'] as String? ?? '',
      dayPart: json['day_part'] as String? ?? 'full',
      dayValue: (json['day_value'] as num?)?.toDouble() ?? 1.0,
      status: leaveRequest['status'] as String? ?? '',
      requestNumber: leaveRequest['request_number'] as String?,
      leaveTypeName: leaveType['name'] as String?,
      leaveTypeColor: leaveType['color'] as String?,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isFullDay => dayPart == 'full';
}

/// Response wrapper for booked days API.
class BookedDaysData {
  final List<String> bookedDates;
  final List<BookedDay> days;

  const BookedDaysData({
    this.bookedDates = const [],
    this.days = const [],
  });

  /// [json] is the `data` object from the API envelope (already unwrapped
  /// by BaseResponse). Contains: month, total_days, booked_dates, days.
  factory BookedDaysData.fromJson(Map<String, dynamic> json) {
    final dates = (json['booked_dates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final daysList = (json['days'] as List<dynamic>?)
            ?.map((e) => BookedDay.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return BookedDaysData(bookedDates: dates, days: daysList);
  }
}
