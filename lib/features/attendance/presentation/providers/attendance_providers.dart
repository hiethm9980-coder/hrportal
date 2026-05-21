import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/attendance_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Check-In / Check-Out Actions
// ═══════════════════════════════════════════════════════════════════

class CheckActionState {
  final bool isLoading;
  final AttendanceRecord? record;
  final UiError? error;

  const CheckActionState({
    this.isLoading = false,
    this.record,
    this.error,
  });
}

class CheckActionNotifier extends StateNotifier<CheckActionState> {
  final Ref _ref;
  CheckActionNotifier(this._ref) : super(const CheckActionState());

  Future<void> checkIn({double? lat, double? lng, String? notes}) async {
    if (state.isLoading) return;
    state = const CheckActionState(isLoading: true);
    try {
      final repo = _ref.read(attendanceRepositoryProvider);
      final record = await repo.checkIn(
        latitude: lat,
        longitude: lng,
        notes: notes,
      );
      state = CheckActionState(record: record);
      // Refresh history.
      _ref.read(attendanceHistoryProvider.notifier).refresh();
    } catch (e) {
      state = CheckActionState(error: GlobalErrorHandler.handle(e));
    }
  }

  Future<void> checkOut({double? lat, double? lng, String? notes}) async {
    if (state.isLoading) return;
    state = const CheckActionState(isLoading: true);
    try {
      final repo = _ref.read(attendanceRepositoryProvider);
      final record = await repo.checkOut(
        latitude: lat,
        longitude: lng,
        notes: notes,
      );
      state = CheckActionState(record: record);
      _ref.read(attendanceHistoryProvider.notifier).refresh();
    } catch (e) {
      state = CheckActionState(error: GlobalErrorHandler.handle(e));
    }
  }

  void clearError() => state = const CheckActionState();
}

final checkActionProvider =
    StateNotifierProvider<CheckActionNotifier, CheckActionState>(
  (ref) => CheckActionNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Paginated Attendance History
// ═══════════════════════════════════════════════════════════════════

class AttendanceHistoryController
    extends PaginatedController<AttendanceRecord> {
  final Ref _ref;

  // ── Filters (kept across pagination) ──
  String? _month;
  String? _dateFrom;
  String? _dateTo;
  List<String> _statuses = const [];

  AttendanceSummary? _summary;
  AttendanceSummary? get summary => _summary;

  /// Public getters so the UI can reflect the current selection in the
  /// filter chips and the date-range button label.
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;
  List<String> get statuses => _statuses;

  AttendanceHistoryController(this._ref) : super(_ref);

  /// Switches to a specific month (legacy entry-point kept for callers
  /// outside this file). Clears any custom date-range.
  void setMonth(String? month) {
    _month = month;
    _dateFrom = null;
    _dateTo = null;
    loadInitial();
  }

  /// Applies date-range + status filters in a single pass and triggers
  /// **one** load. Prefer this over calling [setMonth] then a status
  /// setter (would fire two requests).
  ///
  /// - Pass `null` for either date end to clear the range.
  /// - Pass an empty list for [statuses] to clear the status filter.
  void applyFilters({
    String? dateFrom,
    String? dateTo,
    List<String> statuses = const [],
  }) {
    _dateFrom = dateFrom;
    _dateTo = dateTo;
    _statuses = List.unmodifiable(statuses);
    loadInitial();
  }

  @override
  Future<PaginatedResult<AttendanceRecord>> fetchPage(int page) async {
    final repo = _ref.read(attendanceRepositoryProvider);
    final data = await repo.getHistory(
      month: _month,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      statuses: _statuses.isEmpty ? null : _statuses,
      page: page,
      perPage: 31,
    );
    _summary = data.summary;
    return PaginatedResult(
      items: data.records,
      pagination: data.pagination,
    );
  }
}

final attendanceHistoryProvider = StateNotifierProvider<
    AttendanceHistoryController, PaginatedState<AttendanceRecord>>(
  (ref) {
    final controller = AttendanceHistoryController(ref);
    // الافتراضي: الشهر الحالي (من 1 إلى تاريخ اليوم). الـ AttendanceScreen
    // يضبط الفلاتر فور بناء الـ State (انظر initState فيه).
    return controller;
  },
);
