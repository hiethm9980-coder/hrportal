import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/booked_day_models.dart';

/// State for booked days (approved + pending leaves).
class BookedDaysState {
  final bool isLoading;
  final Map<String, BookedDay> daysByDate; // key = 'yyyy-MM-dd'
  final Set<String> bookedDates;
  final String? error;

  const BookedDaysState({
    this.isLoading = false,
    this.daysByDate = const {},
    this.bookedDates = const {},
    this.error,
  });

  BookedDaysState copyWith({
    bool? isLoading,
    Map<String, BookedDay>? daysByDate,
    Set<String>? bookedDates,
    String? error,
  }) {
    return BookedDaysState(
      isLoading: isLoading ?? this.isLoading,
      daysByDate: daysByDate ?? this.daysByDate,
      bookedDates: bookedDates ?? this.bookedDates,
      error: error,
    );
  }
}

class BookedDaysController extends StateNotifier<BookedDaysState> {
  final Ref _ref;

  BookedDaysController(this._ref) : super(const BookedDaysState());

  /// Load booked days for a specific month (format: YYYYMM).
  Future<void> loadMonth(String month) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      final data = await repo.getBookedDays(month: month);

      // Build a map: date string → BookedDay for quick lookup.
      final map = <String, BookedDay>{};
      for (final day in data.days) {
        map[day.date] = day;
      }

      state = state.copyWith(
        isLoading: false,
        daysByDate: map,
        bookedDates: data.bookedDates.toSet(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final bookedDaysProvider =
    StateNotifierProvider.autoDispose<BookedDaysController, BookedDaysState>(
  (ref) => BookedDaysController(ref),
);
