import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/manager_request_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Manager Requests List (paginated)
// ═══════════════════════════════════════════════════════════════════

class ManagerRequestsListController
    extends PaginatedController<ManagerRequest> {
  final Ref _ref;
  String? _statusFilter;

  ManagerRequestsListController(this._ref) : super(_ref);

  String? get statusFilter => _statusFilter;

  void setStatusFilter(String? status) {
    _statusFilter = status;
    refresh();
  }

  @override
  Future<PaginatedResult<ManagerRequest>> fetchPage(int page) async {
    final repo = _ref.read(managerRequestRepositoryProvider);
    final data = await repo.getRequests(
      page: page,
      perPage: 20,
      status: _statusFilter,
    );
    return PaginatedResult(items: data.requests, pagination: data.pagination);
  }
}

final managerRequestsListProvider = StateNotifierProvider<
    ManagerRequestsListController, PaginatedState<ManagerRequest>>((ref) {
  final controller = ManagerRequestsListController(ref);
  controller.loadInitial();
  return controller;
});

// ═══════════════════════════════════════════════════════════════════
// Manager Request Detail
// ═══════════════════════════════════════════════════════════════════

class ManagerRequestDetailState {
  final ManagerRequestDetail? detail;
  final bool isLoading;
  final UiError? error;

  const ManagerRequestDetailState({
    this.detail,
    this.isLoading = false,
    this.error,
  });

  ManagerRequestDetailState copyWith({
    ManagerRequestDetail? detail,
    bool? isLoading,
    UiError? error,
    bool clearError = false,
  }) {
    return ManagerRequestDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ManagerRequestDetailController
    extends StateNotifier<ManagerRequestDetailState> {
  final Ref _ref;

  ManagerRequestDetailController(this._ref)
      : super(const ManagerRequestDetailState());

  Future<void> loadDetail(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(managerRequestRepositoryProvider);
      final detail = await repo.getRequestDetail(id);
      state = ManagerRequestDetailState(detail: detail);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GlobalErrorHandler.handle(e),
      );
    }
  }
}

final managerRequestDetailProvider = StateNotifierProvider.autoDispose<
    ManagerRequestDetailController, ManagerRequestDetailState>(
  (ref) => ManagerRequestDetailController(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Decide (Approve / Reject) Action
// ═══════════════════════════════════════════════════════════════════

class DecideRequestState {
  final bool isLoading;
  final bool isSuccess;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;

  const DecideRequestState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.fieldErrors = const {},
  });

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors?.isNotEmpty == true ? errors!.first : null;
  }

  DecideRequestState copyWith({
    bool? isLoading,
    bool? isSuccess,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool clearErrors = false,
  }) {
    return DecideRequestState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
    );
  }
}

class DecideRequestController extends StateNotifier<DecideRequestState> {
  final Ref _ref;

  DecideRequestController(this._ref) : super(const DecideRequestState());

  Future<void> decide({
    required int requestId,
    required String status,
    String? responseNotes,
  }) async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final repo = _ref.read(managerRequestRepositoryProvider);
      await repo.decideRequest(
        id: requestId,
        status: status,
        responseNotes: responseNotes,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);

      // Refresh the list after decision
      _ref.read(managerRequestsListProvider.notifier).refresh();
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

final decideRequestProvider = StateNotifierProvider.autoDispose<
    DecideRequestController, DecideRequestState>(
  (ref) => DecideRequestController(ref),
);
