import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';

/// Employee info embedded in a manager request.
class RequestEmployee extends Equatable {
  final int id;
  final String name;
  final String code;

  const RequestEmployee({
    required this.id,
    required this.name,
    required this.code,
  });

  factory RequestEmployee.fromJson(Map<String, dynamic> json) {
    return RequestEmployee(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Approval chain step.
class ApprovalChainStep extends Equatable {
  final int level;
  final String approverType; // direct_manager | user | role
  final String label;

  const ApprovalChainStep({
    required this.level,
    required this.approverType,
    required this.label,
  });

  factory ApprovalChainStep.fromJson(Map<String, dynamic> json) {
    return ApprovalChainStep(
      level: json['level'] as int,
      approverType: json['approver_type'] as String,
      label: json['label'] as String,
    );
  }

  @override
  List<Object?> get props => [level, approverType];
}

/// Attachment on a request.
class RequestAttachment extends Equatable {
  final int id;
  final String originalName;
  final int size;
  final String mimeType;
  final String createdAt;

  const RequestAttachment({
    required this.id,
    required this.originalName,
    required this.size,
    required this.mimeType,
    required this.createdAt,
  });

  factory RequestAttachment.fromJson(Map<String, dynamic> json) {
    return RequestAttachment(
      id: json['id'] as int,
      originalName: json['original_name'] as String,
      size: (json['size'] as num).toInt(),
      mimeType: json['mime_type'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Manager request item (from GET /manager/requests).
class ManagerRequest extends Equatable {
  final int id;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? requestType;
  final String? subject;
  final String? description;
  final int? currentApprovalLevel;
  final String? responseNotes;
  final int? respondedBy;
  final String? respondedAt;
  final RequestEmployee? employee;

  const ManagerRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.requestType,
    this.subject,
    this.description,
    this.currentApprovalLevel,
    this.responseNotes,
    this.respondedBy,
    this.respondedAt,
    this.employee,
  });

  factory ManagerRequest.fromJson(Map<String, dynamic> json) {
    return ManagerRequest(
      id: json['id'] as int,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      requestType: json['request_type'] as String?,
      subject: json['subject'] as String?,
      description: json['description'] as String?,
      currentApprovalLevel: json['current_approval_level'] as int?,
      responseNotes: json['response_notes'] as String?,
      respondedBy: json['responded_by'] as int?,
      respondedAt: json['responded_at'] as String?,
      employee: json['employee'] != null
          ? RequestEmployee.fromJson(json['employee'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Parsed data from GET /manager/requests.
class ManagerRequestsData {
  final List<ManagerRequest> requests;
  final Pagination pagination;

  const ManagerRequestsData({
    required this.requests,
    required this.pagination,
  });

  factory ManagerRequestsData.fromJson(Map<String, dynamic> json) {
    return ManagerRequestsData(
      requests: (json['requests'] as List)
          .map((e) => ManagerRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

/// Full detail from GET /manager/requests/{id}.
class ManagerRequestDetail extends Equatable {
  final int id;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? requestType;
  final String? subject;
  final String? description;
  final int? currentApprovalLevel;
  final String? responseNotes;
  final int? respondedBy;
  final String? respondedAt;
  final RequestEmployee? employee;
  final bool canApprove;
  final List<ApprovalChainStep> approvalChain;
  final List<RequestAttachment> attachments;

  const ManagerRequestDetail({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.requestType,
    this.subject,
    this.description,
    this.currentApprovalLevel,
    this.responseNotes,
    this.respondedBy,
    this.respondedAt,
    this.employee,
    this.canApprove = false,
    this.approvalChain = const [],
    this.attachments = const [],
  });

  factory ManagerRequestDetail.fromJson(Map<String, dynamic> json) {
    return ManagerRequestDetail(
      id: json['id'] as int,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      requestType: json['request_type'] as String?,
      subject: json['subject'] as String?,
      description: json['description'] as String?,
      currentApprovalLevel: json['current_approval_level'] as int?,
      responseNotes: json['response_notes'] as String?,
      respondedBy: json['responded_by'] as int?,
      respondedAt: json['responded_at'] as String?,
      employee: json['employee'] != null
          ? RequestEmployee.fromJson(json['employee'] as Map<String, dynamic>)
          : null,
      canApprove: json['can_approve'] as bool? ?? false,
      approvalChain: json['approval_chain'] != null
          ? (json['approval_chain'] as List)
              .map((e) =>
                  ApprovalChainStep.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((e) =>
                  RequestAttachment.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [id];
}
