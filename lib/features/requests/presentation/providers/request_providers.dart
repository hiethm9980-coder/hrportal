import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/request_models.dart';

// ═══════════════════════════════════════════════════════════════════
// Requests List
// ═══════════════════════════════════════════════════════════════════

class RequestsListState {
  final bool isLoading;
  final List<EmployeeRequest> requests;
  final EmployeeRequestSummary? summary;
  final UiError? error;

  const RequestsListState({
    this.isLoading = false,
    this.requests = const [],
    this.summary,
    this.error,
  });
}

class RequestsListNotifier extends StateNotifier<RequestsListState> {
  final Ref _ref;
  String? _currentStatus;
  String? _currentDateFrom;
  String? _currentDateTo;

  RequestsListNotifier(this._ref) : super(const RequestsListState());

  Future<void> load({
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    _currentStatus = status;
    _currentDateFrom = dateFrom;
    _currentDateTo = dateTo;
    state = RequestsListState(isLoading: true, summary: state.summary);
    try {
      final repo = _ref.read(requestRepositoryProvider);
      final results = await Future.wait([
        repo.getRequests(
          status: status,
          dateFrom: dateFrom,
          dateTo: dateTo,
          perPage: 50,
        ),
        repo.getSummary(),
      ]);
      state = RequestsListState(
        requests: (results[0] as EmployeeRequestsData).requests,
        summary: results[1] as EmployeeRequestSummary,
      );
    } catch (e) {
      state = RequestsListState(error: GlobalErrorHandler.handle(e));
    }
  }

  Future<void> refresh() => load(
        status: _currentStatus,
        dateFrom: _currentDateFrom,
        dateTo: _currentDateTo,
      );

  Future<bool> submitRequest(int id) async {
    try {
      final repo = _ref.read(requestRepositoryProvider);
      await repo.submitRequest(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRequest(int id) async {
    try {
      final repo = _ref.read(requestRepositoryProvider);
      await repo.deleteRequest(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final requestsListProvider =
    StateNotifierProvider<RequestsListNotifier, RequestsListState>(
  (ref) => RequestsListNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Request Types (reference data)
// ═══════════════════════════════════════════════════════════════════

class RequestTypesState {
  final bool isLoading;
  final List<RequestType> types;
  final UiError? error;

  const RequestTypesState({
    this.isLoading = false,
    this.types = const [],
    this.error,
  });
}

class RequestTypesNotifier extends StateNotifier<RequestTypesState> {
  final Ref _ref;
  RequestTypesNotifier(this._ref) : super(const RequestTypesState());

  Future<void> load() async {
    state = const RequestTypesState(isLoading: true);
    try {
      final repo = _ref.read(requestRepositoryProvider);
      final data = await repo.getRequestTypes();
      state = RequestTypesState(types: data.types);
    } catch (e) {
      state = RequestTypesState(error: GlobalErrorHandler.handle(e));
    }
  }
}

final requestTypesProvider =
    StateNotifierProvider<RequestTypesNotifier, RequestTypesState>(
  (ref) => RequestTypesNotifier(ref),
);

// ═══════════════════════════════════════════════════════════════════
// Currencies (reference data)
// ═══════════════════════════════════════════════════════════════════

class CurrenciesState {
  final bool isLoading;
  final List<Currency> currencies;
  final UiError? error;

  const CurrenciesState({
    this.isLoading = false,
    this.currencies = const [],
    this.error,
  });
}

class CurrenciesNotifier extends StateNotifier<CurrenciesState> {
  final Ref _ref;
  CurrenciesNotifier(this._ref) : super(const CurrenciesState());

  Future<void> load() async {
    state = const CurrenciesState(isLoading: true);
    try {
      final repo = _ref.read(requestRepositoryProvider);
      final data = await repo.getCurrencies();
      state = CurrenciesState(currencies: data.currencies);
    } catch (e) {
      state = CurrenciesState(error: GlobalErrorHandler.handle(e));
    }
  }
}

final currenciesProvider =
    StateNotifierProvider<CurrenciesNotifier, CurrenciesState>(
  (ref) => CurrenciesNotifier(ref),
);

/// Resolves the currently selected RequestType from the create form.
final selectedRequestTypeProvider = Provider.autoDispose<RequestType?>((ref) {
  final form = ref.watch(createRequestFormProvider);
  final types = ref.watch(requestTypesProvider).types;
  if (form.requestTypeId == null) return null;
  for (final t in types) {
    if (t.id == form.requestTypeId) return t;
  }
  return null;
});

// ═══════════════════════════════════════════════════════════════════
// Create Request Form
// ═══════════════════════════════════════════════════════════════════

class CreateRequestFormState {
  final int? requestTypeId;
  final String subject;
  final String description;
  final String requestDate;
  final double? amount;
  final int? currencyId;
  final String? attachmentPath;
  final String? attachmentName;

  final bool isLoading;
  final UiError? error;
  final Map<String, List<String>> fieldErrors;
  final bool isSuccess;
  final String? successMessage;

  const CreateRequestFormState({
    this.requestTypeId,
    this.subject = '',
    this.description = '',
    this.requestDate = '',
    this.amount,
    this.currencyId,
    this.attachmentPath,
    this.attachmentName,
    this.isLoading = false,
    this.error,
    this.fieldErrors = const {},
    this.isSuccess = false,
    this.successMessage,
  });

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors?.isNotEmpty == true ? errors!.first : null;
  }

  CreateRequestFormState copyWith({
    int? requestTypeId,
    String? subject,
    String? description,
    String? requestDate,
    double? amount,
    int? currencyId,
    String? attachmentPath,
    String? attachmentName,
    bool? isLoading,
    UiError? error,
    Map<String, List<String>>? fieldErrors,
    bool? isSuccess,
    String? successMessage,
    bool clearErrors = false,
    bool clearAttachment = false,
    bool clearAmount = false,
    bool clearCurrency = false,
  }) {
    return CreateRequestFormState(
      requestTypeId: requestTypeId ?? this.requestTypeId,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      requestDate: requestDate ?? this.requestDate,
      amount: clearAmount ? null : (amount ?? this.amount),
      currencyId: clearCurrency ? null : (currencyId ?? this.currencyId),
      attachmentPath:
          clearAttachment ? null : (attachmentPath ?? this.attachmentPath),
      attachmentName:
          clearAttachment ? null : (attachmentName ?? this.attachmentName),
      isLoading: isLoading ?? this.isLoading,
      error: clearErrors ? null : (error ?? this.error),
      fieldErrors: clearErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      isSuccess: isSuccess ?? this.isSuccess,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class CreateRequestFormController
    extends StateNotifier<CreateRequestFormState> {
  final Ref _ref;
  CreateRequestFormController(this._ref)
      : super(const CreateRequestFormState());

  void setRequestType(int id) {
    // Reset financial fields when changing type — `is_financial` may differ.
    state = state.copyWith(
      requestTypeId: id,
      clearErrors: true,
      clearAmount: true,
    );
  }

  void setSubject(String v) =>
      state = state.copyWith(subject: v, clearErrors: true);

  void setDescription(String v) =>
      state = state.copyWith(description: v, clearErrors: true);

  void setRequestDate(String v) =>
      state = state.copyWith(requestDate: v, clearErrors: true);

  void setAmount(double? v) =>
      state = state.copyWith(amount: v, clearErrors: true);

  void setAttachment(String path, String name) =>
      state = state.copyWith(
        attachmentPath: path,
        attachmentName: name,
        clearErrors: true,
      );

  void clearAttachment() =>
      state = state.copyWith(clearAttachment: true, clearErrors: true);

  Future<void> submit({required String action}) async {
    if (state.isLoading) return;

    // Resolve the selected type directly to avoid circular dependency
    // with selectedRequestTypeProvider (which watches this form provider).
    final types = _ref.read(requestTypesProvider).types;
    RequestType? type;
    for (final t in types) {
      if (t.id == state.requestTypeId) {
        type = t;
        break;
      }
    }

    // ── Client-side validation ──
    final errors = <String, List<String>>{};
    if (state.requestTypeId == null) {
      errors['employee_request_type_id'] = ['This field is required'];
    }
    if (state.subject.trim().isEmpty) {
      errors['subject'] = ['This field is required'];
    }
    // Resolve contract currency for financial requests.
    final contractCurrencyId =
        _ref.read(authProvider).employee?.contract?.currency?.id;

    if (type?.isFinancial == true) {
      if (state.amount == null || state.amount! <= 0) {
        errors['amount'] = ['Enter a valid positive number'];
      }
      if (contractCurrencyId == null) {
        errors['currency_id'] = ['This field is required'];
      }
    }
    if (type?.requiresAttachment == true &&
        (state.attachmentPath == null || state.attachmentPath!.isEmpty)) {
      errors['file'] = ['This request type requires an attachment'];
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, clearErrors: true);

    try {
      final repo = _ref.read(requestRepositoryProvider);
      await repo.createRequest(
        requestTypeId: state.requestTypeId!,
        subject: state.subject.trim(),
        action: action,
        isFinancial: type?.isFinancial ?? false,
        description:
            state.description.isNotEmpty ? state.description : null,
        requestDate:
            state.requestDate.isNotEmpty ? state.requestDate : null,
        amount: state.amount,
        currencyId: contractCurrencyId,
        attachmentPath: state.attachmentPath,
      );
      final msg = action == 'draft'
          ? 'Saved as draft'
          : 'Request submitted successfully';
      state = state.copyWith(
          isLoading: false, isSuccess: true, successMessage: msg);
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
