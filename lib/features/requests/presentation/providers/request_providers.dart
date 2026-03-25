import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/request_models.dart';
import '../../../../shared/controllers/paginated_controller.dart';
import '../../../../shared/controllers/global_error_handler.dart';

// ═══════════════════════════════════════════════════════════════════
// Requests List (paginated)
// ═══════════════════════════════════════════════════════════════════

class RequestsListController extends PaginatedController<EmployeeRequest> {
  final Ref _ref;

  RequestsListController(this._ref) : super(_ref);

  @override
  Future<PaginatedResult<EmployeeRequest>> fetchPage(int page) async {
    final repo = _ref.read(requestRepositoryProvider);
    final data = await repo.getRequests(page: page, perPage: 15);
    return PaginatedResult(items: data.requests, pagination: data.pagination);
  }
}

final requestsListProvider = StateNotifierProvider<RequestsListController,
    PaginatedState<EmployeeRequest>>((ref) {
  final controller = RequestsListController(ref);
  controller.loadInitial();
  return controller;
});

// ═══════════════════════════════════════════════════════════════════
// Create Request Form
// ═══════════════════════════════════════════════════════════════════

class CreateRequestFormState {
  final String requestType;
  final String subject;
  final String description;
  final String currency;
  final bool isLoading;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;
  final bool isSuccess;

  const CreateRequestFormState({
    this.requestType = '',
    this.subject = '',
    this.description = '',
    this.currency = 'YER',
    this.isLoading = false,
    this.error,
    this.fieldErrors = const {},
    this.isSuccess = false,
  });

  bool get isLoanRequest => requestType == 'loan_request';

  bool get canSubmit =>
      requestType.isNotEmpty && subject.isNotEmpty && !isLoading;

  /// The final subject sent to the API.
  /// For loan requests: "12000 YER", otherwise the raw subject.
  String get resolvedSubject =>
      isLoanRequest ? '$subject $currency' : subject;

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors?.isNotEmpty == true ? errors!.first : null;
  }

  CreateRequestFormState copyWith({
    String? requestType,
    String? subject,
    String? description,
    String? currency,
    bool? isLoading,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool? isSuccess,
    bool clearErrors = false,
  }) {
    return CreateRequestFormState(
      requestType: requestType ?? this.requestType,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      isLoading: isLoading ?? this.isLoading,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class CreateRequestFormController extends StateNotifier<CreateRequestFormState> {
  final Ref _ref;
  CreateRequestFormController(this._ref)
      : super(const CreateRequestFormState());

  void setRequestType(String v) =>
      state = state.copyWith(requestType: v.trim(), subject: '', clearErrors: true);

  void setSubject(String v) =>
      state = state.copyWith(subject: v.trim(), clearErrors: true);

  void setCurrency(String v) =>
      state = state.copyWith(currency: v, clearErrors: true);

  void setDescription(String v) =>
      state = state.copyWith(description: v, clearErrors: true);

  Future<void> submit() async {
    if (state.isLoading) return;

    // ── Client-side validation ──
    final errors = <String, List<String>>{};
    if (state.requestType.isEmpty) errors['request_type'] = ['This field is required'];
    if (state.subject.isEmpty) {
      errors['subject'] = ['This field is required'];
    } else if (state.isLoanRequest) {
      final amount = int.tryParse(state.subject);
      if (amount == null || amount <= 0) errors['subject'] = ['Enter a valid positive number'];
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, clearErrors: true);

    try {
      final repo = _ref.read(requestRepositoryProvider);
      await repo.createRequest(
        requestType: state.requestType,
        subject: state.resolvedSubject,
        description: state.description.isEmpty ? null : state.description,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.read(requestsListProvider.notifier).refresh();
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

final createRequestFormProvider = StateNotifierProvider.autoDispose<
    CreateRequestFormController, CreateRequestFormState>(
  (ref) => CreateRequestFormController(ref),
);
