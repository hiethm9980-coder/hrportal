import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';
import '../../../leave/data/models/leave_models.dart';

/// Employee info embedded in a manager leave request.
class LeaveEmployee extends Equatable {
  final int id;
  final String name;
  final String code;
  final String? jobTitle;

  const LeaveEmployee({
    required this.id,
    required this.name,
    required this.code,
    this.jobTitle,
  });

  factory LeaveEmployee.fromJson(Map<String, dynamic> json) {
    return LeaveEmployee(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      jobTitle: json['job_title'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Manager leave item (from GET /manager/leaves).
class ManagerLeave extends Equatable {
  final int id;
  final String? requestNumber;
  final LeaveType? leaveType;
  final String startDate;
  final String endDate;
  final double totalDays;
  final String dayPart;
  final String? reason;
  final String status;
  final String? rejectionReason;
  final int? approvedBy;
  final String? approvedAt;
  final String createdAt;
  final LeaveEmployee? employee;

  const ManagerLeave({
    required this.id,
    this.requestNumber,
    this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.dayPart,
    this.reason,
    required this.status,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    this.employee,
  });

  factory ManagerLeave.fromJson(Map<String, dynamic> json) {
    return ManagerLeave(
      id: json['id'] as int,
      requestNumber: json['request_number'] as String?,
      leaveType: json['leave_type'] != null
          ? LeaveType.fromJson(json['leave_type'] as Map<String, dynamic>)
          : null,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      totalDays: (json['total_days'] as num).toDouble(),
      dayPart: json['day_part'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by'] as int?,
      approvedAt: json['approved_at'] as String?,
      createdAt: json['created_at'] as String,
      employee: json['employee'] != null
          ? LeaveEmployee.fromJson(json['employee'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Parsed data from GET /manager/leaves.
class ManagerLeavesData {
  final List<ManagerLeave> leaves;
  final Pagination pagination;

  const ManagerLeavesData({
    required this.leaves,
    required this.pagination,
  });

  factory ManagerLeavesData.fromJson(Map<String, dynamic> json) {
    return ManagerLeavesData(
      leaves: (json['leaves'] as List)
          .map((e) => ManagerLeave.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}
