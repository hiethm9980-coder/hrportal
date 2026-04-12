import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/holiday_models.dart';

/// State for holidays list.
class HolidaysState {
  final List<Holiday> holidays;
  final int year;
  final bool isLoading;
  final String? error;

  const HolidaysState({
    this.holidays = const [],
    this.year = 0,
    this.isLoading = false,
    this.error,
  });

  HolidaysState copyWith({
    List<Holiday>? holidays,
    int? year,
    bool? isLoading,
    String? error,
  }) {
    return HolidaysState(
      holidays: holidays ?? this.holidays,
      year: year ?? this.year,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Controller for fetching holidays.
class HolidaysController extends StateNotifier<HolidaysState> {
  final Ref _ref;

  HolidaysController(this._ref) : super(const HolidaysState());

  /// Load holidays for the given [year]. Defaults to current year.
  Future<void> load({int? year}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(holidayRepositoryProvider);
      final data = await repo.getHolidays(year: year);
      state = state.copyWith(
        holidays: data.holidays,
        year: data.year,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final holidaysProvider =
    StateNotifierProvider<HolidaysController, HolidaysState>(
  (ref) => HolidaysController(ref),
);
