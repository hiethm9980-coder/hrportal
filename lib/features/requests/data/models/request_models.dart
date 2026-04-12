// ⚠️ API CONTRACT — Employee Requests v1.

import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';
import '../../../../shared/models/approval_models.dart';

export '../../../../shared/models/approval_models.dart'
    show ApprovalChainItem, ApprovalHistoryItem;

// ═══════════════════════════════════════════════════════════════════
// RequestType — from GET /employee-request-types
// ═══════════════════════════════════════════════════════════════════

class RequestType extends Equatable {
  final int id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String name; // localized (server-resolved)
  final int sortOrder;
  final bool isFinancial;
  final bool requiresAmount;
  final bool requiresAttachment;
  final bool isActive;

  const RequestType({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.name,
    required this.sortOrder,
    required this.isFinancial,
    required this.requiresAmount,
    required this.requiresAttachment,
    required this.isActive,
  });

  factory RequestType.fromJson(Map<String, dynamic> json) {
    return RequestType(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      name: (json['name'] as String?) ??
          (json['name_en'] as String?) ??
          (json['name_ar'] as String?) ??
          '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isFinancial: (json['is_financial'] as bool?) ?? false,
      requiresAmount: (json['requires_amount'] as bool?) ?? false,
      requiresAttachment: (json['requires_attachment'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  @override
  List<Object?> get props => [id];
}

class RequestTypesData {
  final List<RequestType> types;

  const RequestTypesData({required this.types});

  factory RequestTypesData.fromJson(Map<String, dynamic> json) {
    final list = (json['request_types'] ?? json['types'] ?? json['data']) as List?;
    return RequestTypesData(
      types: (list ?? const [])
          .map((e) => RequestType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Currency — from GET /currencies
// ═══════════════════════════════════════════════════════════════════

class Currency extends Equatable {
  final int id;
  final String code;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String? symbol;

  const Currency({
    required this.id,
    required this.code,
    required this.name,
    this.nameAr,
    this.nameEn,
    this.symbol,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ??
          (json['name_en'] as String?) ??
          (json['name_ar'] as String?) ??
          '',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      symbol: json['symbol'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

class CurrenciesData {
  final List<Currency> currencies;

  const CurrenciesData({required this.currencies});

  factory CurrenciesData.fromJson(Map<String, dynamic> json) {
    final list = (json['currencies'] ?? json['data']) as List?;
    return CurrenciesData(
      currencies: (list ?? const [])
          .map((e) => Currency.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// RequestApprover — next approver / approval chain item
// ═══════════════════════════════════════════════════════════════════

class RequestApprover extends Equatable {
  final int? userId;
  final String name;
  final int approvalLevel;
  final String decision; // pending|approved|rejected

  const RequestApprover({
    this.userId,
    required this.name,
    required this.approvalLevel,
    required this.decision,
  });

  factory RequestApprover.fromJson(Map<String, dynamic> json) {
    return RequestApprover(
      userId: json['user_id'] as int? ?? json['id'] as int?,
      name: (json['user_name'] as String?) ??
          (json['name'] as String?) ??
          '',
      approvalLevel: (json['approval_level'] as int?) ??
          (json['level'] as int?) ??
          1,
      decision: (json['decision'] as String?) ?? 'pending',
    );
  }

  @override
  List<Object?> get props => [userId, approvalLevel];
}

// ═══════════════════════════════════════════════════════════════════
// EmployeeRequest
// ═══════════════════════════════════════════════════════════════════

class EmployeeRequest extends Equatable {
  final int id;
  final String? requestNumber;
  final String status; // draft|pending|approved|rejected|cancelled
  final String createdAt;
  final String? updatedAt;

  // Type
  final int? requestTypeId;
  final RequestType? requestType;
  final String? requestTypeLabel; // server-resolved label

  // Core fields
  final String? subject;
  final String? description;
  final String? requestDate; // Y-m-d

  // Financial
  final double? amount;
  final int? currencyId;
  final Currency? currency;

  // Approval
  final int? currentApprovalLevel;
  final int? totalLevels;
  final RequestApprover? nextApprover;
  final List<ApprovalChainItem> approvalChain;
  final List<ApprovalHistoryItem> approvalHistory;

  // Attachment
  final String? attachmentPath;
  final String? attachmentUrl;
  final String? attachmentName;

  // Response
  final String? responseNotes;
  final int? respondedBy;
  final String? respondedAt;

  const EmployeeRequest({
    required this.id,
    this.requestNumber,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.requestTypeId,
    this.requestType,
    this.requestTypeLabel,
    this.subject,
    this.description,
    this.requestDate,
    this.amount,
    this.currencyId,
    this.currency,
    this.currentApprovalLevel,
    this.totalLevels,
    this.nextApprover,
    this.approvalChain = const [],
    this.approvalHistory = const [],
    this.attachmentPath,
    this.attachmentUrl,
    this.attachmentName,
    this.responseNotes,
    this.respondedBy,
    this.respondedAt,
  });

  factory EmployeeRequest.fromJson(Map<String, dynamic> json) {
    return EmployeeRequest(
      id: json['id'] as int,
      requestNumber: json['request_number'] as String?,
      status: json['status'] as String,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: json['updated_at'] as String?,
      requestTypeId: json['employee_request_type_id'] as int? ??
          json['request_type_id'] as int?,
      requestType: json['request_type'] is Map<String, dynamic>
          ? RequestType.fromJson(json['request_type'] as Map<String, dynamic>)
          : null,
      requestTypeLabel: json['request_type_label'] as String? ??
          (json['request_type'] is String ? json['request_type'] as String : null),
      subject: json['subject'] as String?,
      description: json['description'] as String?,
      requestDate: json['request_date'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currencyId: json['currency_id'] as int?,
      currency: json['currency'] is Map<String, dynamic>
          ? Currency.fromJson(json['currency'] as Map<String, dynamic>)
          : null,
      currentApprovalLevel: json['current_approval_level'] as int?,
      totalLevels: json['total_levels'] as int?,
      nextApprover: json['next_approver'] is Map<String, dynamic>
          ? RequestApprover.fromJson(
              json['next_approver'] as Map<String, dynamic>)
          : null,
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
      attachmentPath: json['attachment_path'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      responseNotes: json['response_notes'] as String?,
      respondedBy: json['responded_by'] as int?,
      respondedAt: json['responded_at'] as String?,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';
  bool get canSubmit => isDraft;
  bool get canDelete => isDraft;
  bool get isFinancial =>
      requestType?.isFinancial == true || amount != null;

  /// The current pending approver (the one blocking the request right now),
  /// if any. Picked from `approval_history` first since it carries
  /// localized labels and the live `is_current` flag.
  ApprovalHistoryItem? get currentApprover {
    for (final h in approvalHistory) {
      if (h.isCurrent && h.decision == 'pending') return h;
    }
    return null;
  }

  /// Display name for the current approver. Prefers a real user name,
  /// then the snapshot role label from the history item.
  String currentApproverDisplay(bool isAr) {
    final h = currentApprover;
    if (h != null) {
      if (h.approverName != null && h.approverName!.isNotEmpty) {
        return h.approverName!;
      }
      final label = h.resolvedLabel(isAr);
      if (label.isNotEmpty) return label;
    }
    if (nextApprover != null && nextApprover!.name.isNotEmpty) {
      return nextApprover!.name;
    }
    return '';
  }

  @override
  List<Object?> get props => [id];
}

// ═══════════════════════════════════════════════════════════════════
// EmployeeRequestsData (paginated list)
// ═══════════════════════════════════════════════════════════════════

class EmployeeRequestsData {
  final List<EmployeeRequest> requests;
  final Pagination pagination;

  const EmployeeRequestsData({
    required this.requests,
    required this.pagination,
  });

  factory EmployeeRequestsData.fromJson(Map<String, dynamic> json) {
    final list = (json['employee_requests'] ?? json['requests']) as List;
    return EmployeeRequestsData(
      requests: list
          .map((e) => EmployeeRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EmployeeRequestSummary
// ═══════════════════════════════════════════════════════════════════

class EmployeeRequestSummary extends Equatable {
  final int total;
  final int draft;
  final int pending;
  final int approved;
  final int rejected;
  final int cancelled;

  const EmployeeRequestSummary({
    required this.total,
    required this.draft,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.cancelled,
  });

  factory EmployeeRequestSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeRequestSummary(
      total: (json['total'] as int?) ?? 0,
      draft: (json['draft'] as int?) ?? 0,
      pending: (json['pending'] as int?) ?? 0,
      approved: (json['approved'] as int?) ?? 0,
      rejected: (json['rejected'] as int?) ?? 0,
      cancelled: (json['cancelled'] as int?) ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [total, draft, pending, approved, rejected, cancelled];
}

// ═══════════════════════════════════════════════════════════════════
// Backwards-compat alias used by other features (manager_requests, etc).
// Keeps the old name for any callers still importing RequestsData.
// ═══════════════════════════════════════════════════════════════════
typedef RequestsData = EmployeeRequestsData;
