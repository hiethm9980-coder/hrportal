import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/request_models.dart';

/// Repository for employee requests.
///
/// Endpoints:
/// - GET    /employee-request-types
/// - GET    /currencies
/// - GET    /employee-requests
/// - GET    /employee-requests/summary
/// - GET    /employee-requests/{id}
/// - POST   /employee-requests
/// - POST   /employee-requests/{id}/submit
/// - DELETE /employee-requests/{id}
class RequestRepository {
  final ApiClient _client;

  RequestRepository({required ApiClient client}) : _client = client;

  // ── Reference data ─────────────────────────────────────────────────

  Future<RequestTypesData> getRequestTypes() async {
    final response = await _client.get<RequestTypesData>(
      ApiConstants.employeeRequestTypes,
      fromJson: (json) =>
          RequestTypesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CurrenciesData> getCurrencies() async {
    final response = await _client.get<CurrenciesData>(
      ApiConstants.currencies,
      fromJson: (json) =>
          CurrenciesData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  // ── List / detail / summary ────────────────────────────────────────

  Future<EmployeeRequestsData> getRequests({
    int page = 1,
    int perPage = 15,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _client.get<EmployeeRequestsData>(
      ApiConstants.employeeRequests,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      },
      fromJson: (json) =>
          EmployeeRequestsData.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<EmployeeRequestSummary> getSummary() async {
    final response = await _client.get<EmployeeRequestSummary>(
      ApiConstants.employeeRequestsSummary,
      fromJson: (json) =>
          EmployeeRequestSummary.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<EmployeeRequest> getRequestDetail(int id) async {
    final response = await _client.get<EmployeeRequest>(
      ApiConstants.employeeRequestDetail(id),
      fromJson: (json) =>
          EmployeeRequest.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  // ── Mutations ──────────────────────────────────────────────────────

  /// Create an employee request.
  ///
  /// [action] = 'draft' or 'submit'.
  /// When [isFinancial] is true, [amount] and [currencyId] MUST be provided.
  /// When false, they are NOT sent (server rejects them).
  Future<EmployeeRequest> createRequest({
    required int requestTypeId,
    required String subject,
    required String action,
    required bool isFinancial,
    String? description,
    String? requestDate,
    double? amount,
    int? currencyId,
    String? attachmentPath,
  }) async {
    final fields = <String, dynamic>{
      'request_type_id': requestTypeId,
      'subject': subject,
      'action': action,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (requestDate != null && requestDate.isNotEmpty)
        'request_date': requestDate,
      if (isFinancial && amount != null) 'amount': amount,
      if (isFinancial && currencyId != null) 'currency_id': currencyId,
    };

    Object data;
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      final filename = attachmentPath.split(RegExp(r'[/\\]')).last;
      data = FormData.fromMap({
        ...fields,
        'file':
            await MultipartFile.fromFile(attachmentPath, filename: filename),
      });
    } else {
      data = fields;
    }

    final response = await _client.post<EmployeeRequest>(
      ApiConstants.employeeRequests,
      data: data,
      fromJson: (json) =>
          EmployeeRequest.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Submit a draft request for approval.
  Future<void> submitRequest(int id) async {
    await _client.post<void>(ApiConstants.employeeRequestSubmit(id));
  }

  /// Delete (cancel) a request.
  Future<void> deleteRequest(int id) async {
    await _client.delete<void>(ApiConstants.employeeRequestDelete(id));
  }
}
