import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/leave_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Leaves List (balances + requests + types)
// ═══════════════════════════════════════════════════════════════════

class LeavesListState {
  final bool isLoading;
  final List<LeaveBalance> balances;
  final List<LeaveRequest> requests;
  final List<LeaveType> leaveTypes;
  final UiError? error;

  const LeavesListState({
    this.isLoading = false,
    this.balances = const [],
    this.requests = const [],
    this.leaveTypes = const [],
    this.error,
  });
}

class LeavesListNotifier extends StateNotifier<LeavesListState> {
  final Ref _ref;
  LeavesListNotifier(this._ref) : super(const LeavesListState());

  Future<void> load({int? year, String? status}) async {
    state = const LeavesListState(isLoading: true);
    try {
      final repo = _ref.read(leaveRepositoryProvider);
      final data = await repo.getLeaves(year: year, status: status);
      state = LeavesListState(
        balances: data.balances,
        requests: data.requests,
        leaveTypes: data.leaveTypes,
      );
    } catch (e) {
      state = LeavesListState(error: GlobalErrorHandler.handle(e));
    }
  }

  Future<void> refresh() => load();
}

final leavesListProvider =
    StateNotifierProvider<LeavesListNotifier, LeavesListState>(
  (ref) {
    final notifier = LeavesListNotifier(ref);
    notifier.load();
    return notifier;
  },
);

// ═══════════════════════════════════════════════════════════════════
// Create Leave Form
// ═══════════════════════════════════════════════════════════════════

class CreateLeaveFormState {
  final int? leaveTypeId;
  final String startDate;
  final String endDate;
  final String dayPart;
  final String reason;
  final bool isLoading;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;
  final bool isSuccess;

  const CreateLeaveFormState({
    this.leaveTypeId,
    this.startDate = '',
    this.endDate = '',
    this.dayPart = 'full',
    this.reason = '',
    this.isLoading = false,
    this.error,
    this.fieldErrors = const {},
    this.isSuccess = false,
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
    String? dayPart,
    String? reason,
    bool? isLoading,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool? isSuccess,
    bool clearErrors = false,
  }) {
    return CreateLeaveFormState(
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dayPart: dayPart ?? this.dayPart,
      reason: reason ?? this.reason,
      isLoading: isLoading ?? this.isLoading,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      isSuccess: isSuccess ?? this.isSuccess,
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
  void setDayPart(String p) =>
      state = state.copyWith(dayPart: p, clearErrors: true);
  void setReason(String r) =>
      state = state.copyWith(reason: r, clearErrors: true);

  Future<void> submit() async {
    if (state.isLoading) return;

    // ── Client-side validation ──
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
        dayPart: state.dayPart,
        reason: state.reason.isEmpty ? null : state.reason,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
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
