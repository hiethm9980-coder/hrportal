import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/manager_leave_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Manager Leaves List (paginated)
// ═══════════════════════════════════════════════════════════════════

class ManagerLeavesListController
    extends PaginatedController<ManagerLeave> {
  final Ref _ref;
  String? _statusFilter;

  ManagerLeavesListController(this._ref) : super(_ref);

  String? get statusFilter => _statusFilter;

  void setStatusFilter(String? status) {
    _statusFilter = status;
    refresh();
  }

  @override
  Future<PaginatedResult<ManagerLeave>> fetchPage(int page) async {
    final repo = _ref.read(managerLeaveRepositoryProvider);
    final data = await repo.getLeaves(
      page: page,
      perPage: 20,
      status: _statusFilter,
    );
    return PaginatedResult(items: data.leaves, pagination: data.pagination);
  }
}

final managerLeavesListProvider = StateNotifierProvider<
    ManagerLeavesListController, PaginatedState<ManagerLeave>>((ref) {
  final controller = ManagerLeavesListController(ref);
  controller.loadInitial();
  return controller;
});

// ═══════════════════════════════════════════════════════════════════
// Decide (Approve / Reject) Leave Action
// ═══════════════════════════════════════════════════════════════════

class DecideLeaveState {
  final bool isLoading;
  final bool isSuccess;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;

  const DecideLeaveState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.fieldErrors = const {},
  });

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors?.isNotEmpty == true ? errors!.first : null;
  }

  DecideLeaveState copyWith({
    bool? isLoading,
    bool? isSuccess,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool clearErrors = false,
  }) {
    return DecideLeaveState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
    );
  }
}

class DecideLeaveController extends StateNotifier<DecideLeaveState> {
  final Ref _ref;

  DecideLeaveController(this._ref) : super(const DecideLeaveState());

  Future<void> decide({
    required int leaveId,
    required String status,
    String? rejectionReason,
  }) async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final repo = _ref.read(managerLeaveRepositoryProvider);
      await repo.decideLeave(
        id: leaveId,
        status: status,
        rejectionReason: rejectionReason,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);

      // Refresh the list after decision
      _ref.read(managerLeavesListProvider.notifier).refresh();
    } on ValidationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
        fieldErrors: e.fieldErrors,
      );
    } on BusinessRuleException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    }
  }
}

final decideLeaveProvider = StateNotifierProvider.autoDispose<
    DecideLeaveController, DecideLeaveState>(
  (ref) => DecideLeaveController(ref),
);
