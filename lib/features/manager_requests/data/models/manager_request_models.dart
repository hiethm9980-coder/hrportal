import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';
import '../../../../shared/models/approval_models.dart';

export '../../../../shared/models/approval_models.dart'
    show ApprovalChainItem, ApprovalHistoryItem;

/// Employee info embedded in a manager (other) request.
class RequestEmployee extends Equatable {
  final int id;
  final String name;
  final String code;
  final String? jobTitle;
  final String? photoUrl;
  final String? departmentName;

  const RequestEmployee({
    required this.id,
    required this.name,
    required this.code,
    this.jobTitle,
    this.photoUrl,
    this.departmentName,
  });

  factory RequestEmployee.fromJson(Map<String, dynamic> json) {
    final department = json['department'];
    return RequestEmployee(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      jobTitle: json['job_title'] as String?,
      photoUrl: json['photo_url'] as String?,
      departmentName: department is Map<String, dynamic>
          ? department['name'] as String?
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Manager request item (from GET /approvals/requests).
class ManagerRequest extends Equatable {
  final int id;
  final String? requestNumber;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? requestType;
  final String? subject;
  final String? description;
  final int? currentApprovalLevel;
  final int? totalLevels;
  final String? responseNotes;
  final String? respondedAt;
  final RequestEmployee? employee;
  final bool canDecide;
  final List<ApprovalChainItem> approvalChain;
  final List<ApprovalHistoryItem> approvalHistory;
  /// Financial fields.
  final double? amount;
  final int? currencyId;
  final ManagerRequestCurrency? currency;
  /// Single attachment — backend stores at most one file per employee request.
  final String? attachmentPath;
  final String? attachmentUrl;

  const ManagerRequest({
    required this.id,
    this.requestNumber,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.requestType,
    this.subject,
    this.description,
    this.currentApprovalLevel,
    this.totalLevels,
    this.responseNotes,
    this.respondedAt,
    this.employee,
    this.canDecide = false,
    this.approvalChain = const [],
    this.approvalHistory = const [],
    this.amount,
    this.currencyId,
    this.currency,
    this.attachmentPath,
    this.attachmentUrl,
  });

  bool get hasAttachment =>
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) ||
      (attachmentPath != null && attachmentPath!.isNotEmpty);

  factory ManagerRequest.fromJson(Map<String, dynamic> json) {
    final employeeJson =
        (json['requester'] ?? json['employee']) as Map<String, dynamic>?;

    return ManagerRequest(
      id: (json['id'] as num).toInt(),
      requestNumber: json['request_number'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: json['updated_at'] as String?,
      requestType: json['request_type'] as String?,
      subject: json['subject'] as String?,
      description: json['description'] as String?,
      currentApprovalLevel: (json['current_approval_level'] as num?)?.toInt(),
      totalLevels: (json['total_levels'] as num?)?.toInt(),
      responseNotes: json['response_notes'] as String?,
      respondedAt: json['responded_at'] as String?,
      employee:
          employeeJson != null ? RequestEmployee.fromJson(employeeJson) : null,
      canDecide: (json['can_decide'] as bool?) ??
          ((json['status'] as String?)?.toLowerCase() == 'pending'),
      approvalChain: (json['approval_chain'] as List?)
              ?.map((e) =>
                  ApprovalChainItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      approvalHistory: (json['approval_history'] as List?)
              ?.map((e) =>
                  ApprovalHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      amount: (json['amount'] as num?)?.toDouble(),
      currencyId: (json['currency_id'] as num?)?.toInt(),
      currency: json['currency'] is Map<String, dynamic>
          ? ManagerRequestCurrency.fromJson(
              json['currency'] as Map<String, dynamic>)
          : null,
      attachmentPath: json['attachment_path'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Parsed data from GET /approvals/requests.
class ManagerRequestsData {
  final List<ManagerRequest> requests;
  final Pagination pagination;

  const ManagerRequestsData({
    required this.requests,
    required this.pagination,
  });

  factory ManagerRequestsData.fromJson(Map<String, dynamic> json) {
    final list = (json['requests'] ?? json['data']) as List? ?? const [];
    return ManagerRequestsData(
      requests: list
          .map((e) => ManagerRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

/// Currency info embedded in a manager request.
class ManagerRequestCurrency extends Equatable {
  final int id;
  final String code;
  final String name;
  final String? symbol;

  const ManagerRequestCurrency({
    required this.id,
    required this.code,
    required this.name,
    this.symbol,
  });

  factory ManagerRequestCurrency.fromJson(Map<String, dynamic> json) {
    return ManagerRequestCurrency(
      id: (json['id'] as num).toInt(),
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      symbol: json['symbol'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Detail alias — the list item already carries everything.
typedef ManagerRequestDetail = ManagerRequest;
