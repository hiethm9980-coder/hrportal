// ⚠️ API CONTRACT v1.0.0 — Models match §3.1 and §3.3.

import 'package:equatable/equatable.dart';

import '../../../profile/data/models/employee_profile_model.dart';
import '../../../../shared/models/approvals_flags.dart';

/// Successful login payload.
///
/// Contract (simplified):
/// `{ token, token_type, employee, approvals?, managed_companies? }`
class LoginData extends Equatable {
  final String token;
  final String tokenType;
  final EmployeeProfile employee;
  final ApprovalsFlags? approvals;
  final List<ManagedCompany> managedCompanies;

  const LoginData({
    required this.token,
    required this.tokenType,
    required this.employee,
    this.approvals,
    this.managedCompanies = const [],
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      token: json['token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      employee: EmployeeProfile.fromJson(
        json['employee'] as Map<String, dynamic>,
      ),
      approvals: json['approvals'] is Map<String, dynamic>
          ? ApprovalsFlags.fromJson(
              json['approvals'] as Map<String, dynamic>,
            )
          : null,
      managedCompanies: (json['managed_companies'] as List?)
              ?.map((e) =>
                  ManagedCompany.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'token_type': tokenType,
        'employee': employee.toJson(),
        if (approvals != null) 'approvals': approvals!.toJson(),
        'managed_companies':
            managedCompanies.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props =>
      [token, tokenType, employee, approvals, managedCompanies];
}

/// Logout-all payload.
///
/// Contract example:
/// `{ revoked_tokens: 3 }`
class LogoutAllData extends Equatable {
  final int revokedTokens;

  const LogoutAllData({required this.revokedTokens});

  factory LogoutAllData.fromJson(Map<String, dynamic> json) {
    return LogoutAllData(
      revokedTokens: (json['revoked_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'revoked_tokens': revokedTokens,
      };

  @override
  List<Object?> get props => [revokedTokens];
}

/// Wrapper returned by GET /me — includes approval flags and managed companies
/// alongside the employee profile.
class CurrentUserData extends Equatable {
  final EmployeeProfile employee;
  final ApprovalsFlags? approvals;
  final List<ManagedCompany> managedCompanies;

  const CurrentUserData({
    required this.employee,
    this.approvals,
    this.managedCompanies = const [],
  });

  factory CurrentUserData.fromJson(Map<String, dynamic> json) {
    // The /me endpoint may return either the employee fields directly,
    // or wrap them in `{ employee: {...}, approvals: {...}, managed_companies: [...] }`.
    final employeeJson = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : json;

    return CurrentUserData(
      employee: EmployeeProfile.fromJson(employeeJson),
      approvals: json['approvals'] is Map<String, dynamic>
          ? ApprovalsFlags.fromJson(
              json['approvals'] as Map<String, dynamic>,
            )
          : null,
      managedCompanies: (json['managed_companies'] as List?)
              ?.map((e) =>
                  ManagedCompany.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [employee, approvals, managedCompanies];
}
