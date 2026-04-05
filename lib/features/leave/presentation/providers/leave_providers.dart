import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/leave_models.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Leaves List
// ═══════════════════════════════════════════════════════════════════

class LeavesListState {
  final bool isLoading;
  final List<LeaveRequest> requests;
  final LeaveSummary? summary;
  final UiError? error;

  const LeavesListState({
    this.isLoading = false,
    this.requests = const [],
    this.summary,
    this.error,
  });
}

class LeavesListNotifier extends StateNotifier<LeavesListState> {
  final Ref _ref;
  String? _currentStatus;
  String? _currentDateFrom;
  String? _currentDateTo;

  LeavesListNotifier(this._ref) : super(const LeavesListState());

  Future<void> load({String? status, String? dateFrom, String? dateTo}) async {
    _currentStatus = status;
    _currentDateFrom = dateFrom;
    _currentDateTo = dateTo;
    state = LeavesListState(isLoading: true, summary: state.summary);
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      // Fetch list and summary in parallel
      final results = await Future.wait([
        repo.getLeaves(status: status, dateFrom: dateFrom, dateTo: dateTo),
        repo.getSummary(),
      ]);
      state = LeavesListState(
        requests: (results[0] as LeavesData).requests,
        summary: results[1] as LeaveSummary,
      );
    } catch (e) {
      state = LeavesListState(error: GlobalErrorHandler.handle(e));
    }
  }

  Future<void> refresh() => load(
        status: _currentStatus,
        dateFrom: _currentDateFrom,
        dateTo: _currentDateTo,
      );

  Future<bool> submitLeave(int id) async {
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      await repo.submitLeave(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLeave(int id) async {
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      await repo.deleteLeave(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final leavesListProvider =
    StateNotifierProvider<LeavesListNotifier, LeavesListState>(
  (ref) => LeavesListNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Leave Balances
// ═══════════════════════════════════════════════════════════════════

class LeaveBalancesState {
  final bool isLoading;
  final List<LeaveBalance> balances;
  final UiError? error;

  const LeaveBalancesState({
    this.isLoading = false,
    this.balances = const [],
    this.error,
  });
}

class LeaveBalancesNotifier extends StateNotifier<LeaveBalancesState> {
  final Ref _ref;
  LeaveBalancesNotifier(this._ref) : super(const LeaveBalancesState());

  Future<void> load() async {
    state = const LeaveBalancesState(isLoading: true);
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      final data = await repo.getBalances();
      state = LeaveBalancesState(balances: data.balances);
    } catch (e) {
      state = LeaveBalancesState(error: GlobalErrorHandler.handle(e));
    }
  }
}

final leaveBalancesProvider =
    StateNotifierProvider.autoDispose<LeaveBalancesNotifier, LeaveBalancesState>(
  (ref) => LeaveBalancesNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Create Leave Form
// ═══════════════════════════════════════════════════════════════════

class CreateLeaveFormState {
  final int? leaveTypeId;
  final String startDate;
  final String endDate;
  final String reason;
  final bool isLoading;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;
  final bool isSuccess;
  final String? successMessage;

  const CreateLeaveFormState({
    this.leaveTypeId,
    this.startDate = '',
    this.endDate = '',
    this.reason = '',
    this.isLoading = false,
    this.error,
    this.fieldErrors = const {},
    this.isSuccess = false,
    this.successMessage,
  });

  bool get canSubmit =>
      leaveTypeId != null &&
      startDate.isNotEmpty &&
      endDate.isNotEmpty &&
      !isLoading;

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors?.isNotEmpty == true ? errors!.first : null;
  }

  CreateLeaveFormState copyWith({
    int? leaveTypeId,
    String? startDate,
    String? endDate,
    String? reason,
    bool? isLoading,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool? isSuccess,
    String? successMessage,
    bool clearErrors = false,
    bool clearLeaveType = false,
  }) {
    return CreateLeaveFormState(
      leaveTypeId: clearLeaveType ? null : (leaveTypeId ?? this.leaveTypeId),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      isLoading: isLoading ?? this.isLoading,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      isSuccess: isSuccess ?? this.isSuccess,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class CreateLeaveFormController extends StateNotifier<CreateLeaveFormState> {
  final Ref _ref;
  CreateLeaveFormController(this._ref) : super(const CreateLeaveFormState());

  void setLeaveType(int id) =>
      state = state.copyWith(leaveTypeId: id, clearErrors: true);
  void setStartDate(String d) =>
      state = state.copyWith(startDate: d, clearErrors: true);
  void setEndDate(String d) =>
      state = state.copyWith(endDate: d, clearErrors: true);
  void setReason(String v) =>
      state = state.copyWith(reason: v);
  void setDateRange(String start, String end) =>
      state = state.copyWith(startDate: start, endDate: end, clearErrors: true);

  Future<void> submit({required String action}) async {
    if (state.isLoading) return;

    final errors = <String, List<String>>{};
    if (state.leaveTypeId == null) errors['leave_type_id'] = ['This field is required'];
    if (state.startDate.isEmpty) errors['start_date'] = ['This field is required'];
    if (state.endDate.isEmpty) errors['end_date'] = ['This field is required'];
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, clearErrors: true);

    try {
      final repo = _ref.read(leaveRepositoryProvider);
      await repo.createLeave(
        leaveTypeId: state.leaveTypeId!,
        startDate: state.startDate,
        endDate: state.endDate,
        action: action,
        reason: state.reason.isNotEmpty ? state.reason : null,
      );
      final msg = action == 'draft' ? 'Saved as draft' : 'Leave request sent successfully';
      state = state.copyWith(isLoading: false, isSuccess: true, successMessage: msg);
      _ref.read(leavesListProvider.notifier).refresh();
    } on ValidationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
        fieldErrors: e.fieldErrors,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    }
  }
}

final createLeaveFormProvider = StateNotifierProvider.autoDispose<
    CreateLeaveFormController, CreateLeaveFormState>(
  (ref) => CreateLeaveFormController(ref),
);
