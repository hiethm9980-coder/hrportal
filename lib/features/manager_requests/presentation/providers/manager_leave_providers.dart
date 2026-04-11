import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/manager_leave_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// Selected company filter (shared by both approval lists)
// ═══════════════════════════════════════════════════════════════════

/// Currently-selected company id used to scope approval lists.
/// `null` means "default" (the user's primary company on the backend).
final selectedApprovalCompanyIdProvider = StateProvider<int?>((ref) => null);

// ═══════════════════════════════════════════════════════════════════
// Pending counts — lightweight providers that do NOT affect GoRouter.
// ═══════════════════════════════════════════════════════════════════

/// Live pending-leave count. Updated by a quick `filter=pending&per_page=1`
/// API call so the tab label always shows the real number.
final pendingLeavesCountProvider = StateProvider<int>((ref) {
  // Seed from the auth state so the first render is correct.
  return ref.read(authProvider).approvals?.pendingLeavesCount ?? 0;
});

/// Live pending-request count.
final pendingRequestsCountProvider = StateProvider<int>((ref) {
  return ref.read(authProvider).approvals?.pendingRequestsCount ?? 0;
});

// ═══════════════════════════════════════════════════════════════════
// Manager Leaves List (paginated)
// ═══════════════════════════════════════════════════════════════════

class ManagerLeavesListController
    extends PaginatedController<ManagerLeave> {
  final Ref _ref;
  // Default filter = 'awaiting_me' so the first view shows actionable items.
  String? _filterKey = 'awaiting_me';
  int? _companyId;

  ManagerLeavesListController(this._ref) : super(_ref);

  String? get statusFilter => _filterKey;
  int? get companyId => _companyId;

  /// Map UI filter key → API query params (filter + is_current).
  static ({String? filter, int? isCurrent}) _toApiParams(String? key) {
    switch (key) {
      case 'awaiting_me':
        return (filter: 'pending', isCurrent: 1);
      case 'pending':
        return (filter: 'pending', isCurrent: 0);
      case 'approved':
        return (filter: 'approved', isCurrent: null);
      case 'rejected':
        return (filter: 'rejected', isCurrent: null);
      default:
        return (filter: null, isCurrent: null); // all
    }
  }

  void setStatusFilter(String? key) {
    _filterKey = key;
    refresh();
  }

  void setCompanyId(int? companyId) {
    if (_companyId == companyId) return;
    _companyId = companyId;
    refresh();
  }

  @override
  Future<PaginatedResult<ManagerLeave>> fetchPage(int page) async {
    final params = _toApiParams(_filterKey);
    final repo = _ref.read(managerLeaveRepositoryProvider);
    final data = await repo.getLeaves(
      page: page,
      perPage: 20,
      filter: params.filter,
      companyId: _companyId,
      isCurrent: params.isCurrent,
    );
    return PaginatedResult(items: data.leaves, pagination: data.pagination);
  }

  /// Fetch the total pending count with a lightweight API call.
  Future<void> refreshPendingCount() async {
    try {
      final repo = _ref.read(managerLeaveRepositoryProvider);
      final data = await repo.getLeaves(
        page: 1,
        perPage: 1,
        filter: 'pending',
        companyId: _companyId,
      );
      _ref.read(pendingLeavesCountProvider.notifier).state =
          data.pagination.total;
    } catch (_) {
      // Stale count is acceptable.
    }
  }
}

final managerLeavesListProvider = StateNotifierProvider<
    ManagerLeavesListController, PaginatedState<ManagerLeave>>((ref) {
  final controller = ManagerLeavesListController(ref);
  // React to company filter changes globally.
  ref.listen<int?>(selectedApprovalCompanyIdProvider, (prev, next) {
    controller.setCompanyId(next);
  });
  controller._companyId = ref.read(selectedApprovalCompanyIdProvider);
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

      // Refresh the list after decision (the company-manager bypass may stamp
      // multiple levels at once, so a hard refresh is required, not just the
      // single item).
      _ref.read(managerLeavesListProvider.notifier).refresh();
      // Update pending leave count via lightweight API call — avoids mutating
      // authProvider which would trigger a GoRouter rebuild.
      _ref.read(managerLeavesListProvider.notifier).refreshPendingCount();
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
