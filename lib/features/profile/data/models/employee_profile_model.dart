// ⚠️ API CONTRACT v1.0.0 — Fields match §10.1 exactly. Do not rename or remove.

import 'package:equatable/equatable.dart';

/// Employee profile as returned by GET /employee/profile and GET /auth/me.
///
/// Contract: §10.1 EmployeeProfile
class EmployeeProfile extends Equatable {
  // ── Non-nullable ──
  final int id;
  final String code;
  final String name;
  final String initials;
  final String employmentStatus;

  // ── Nullable ──
  final String? nameEn;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? address;
  final String? photoUrl;
  final String? jobTitle;
  final String? hireDate;       // Y-m-d
  final String? gender;         // male|female
  final String? nationality;
  final String? dateOfBirth;    // Y-m-d
  final String? idNumber;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  // ── Nested objects (nullable) ──
  final ProfileDepartment? department;
  final ProfileCompany? company;
  final ProfileManager? manager;
  final ProfileContract? contract;

  // ── Permissions (optional — returned by login/me) ──
  final List<String> permissions;

  // ── Manager flag (from API: is_manager = 0|1) ──
  final bool isManager;

  const EmployeeProfile({
    required this.id,
    required this.code,
    required this.name,
    required this.initials,
    required this.employmentStatus,
    this.nameEn,
    this.email,
    this.phone,
    this.mobile,
    this.address,
    this.photoUrl,
    this.jobTitle,
    this.hireDate,
    this.gender,
    this.nationality,
    this.dateOfBirth,
    this.idNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.department,
    this.company,
    this.manager,
    this.contract,
    this.permissions = const [],
    this.isManager = false,
  });

  /// Whether this employee can manage (approve/reject) requests.
  bool get canManageRequests =>
      isManager || permissions.contains('hr_employee_requests.update');

  /// Create a copy with overridden fields.
  EmployeeProfile copyWith({bool? isManager}) {
    return EmployeeProfile(
      id: id,
      code: code,
      name: name,
      initials: initials,
      employmentStatus: employmentStatus,
      nameEn: nameEn,
      email: email,
      phone: phone,
      mobile: mobile,
      address: address,
      photoUrl: photoUrl,
      jobTitle: jobTitle,
      hireDate: hireDate,
      gender: gender,
      nationality: nationality,
      dateOfBirth: dateOfBirth,
      idNumber: idNumber,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      department: department,
      company: company,
      manager: manager,
      contract: contract,
      permissions: permissions,
      isManager: isManager ?? this.isManager,
    );
  }

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      initials: json['initials'] as String,
      employmentStatus: json['employment_status'] as String,
      nameEn: json['name_en'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      mobile: json['mobile'] as String?,
      address: json['address'] as String?,
      photoUrl: json['photo_url'] as String?,
      jobTitle: json['job_title'] as String?,
      hireDate: json['hire_date'] as String?,
      gender: json['gender'] as String?,
      nationality: json['nationality'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      idNumber: json['id_number'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      department: json['department'] != null
          ? ProfileDepartment.fromJson(
              json['department'] as Map<String, dynamic>)
          : null,
      company: json['company'] != null
          ? ProfileCompany.fromJson(json['company'] as Map<String, dynamic>)
          : null,
      manager: json['manager'] != null
          ? ProfileManager.fromJson(json['manager'] as Map<String, dynamic>)
          : null,
      contract: json['contract'] != null
          ? ProfileContract.fromJson(
              json['contract'] as Map<String, dynamic>)
          : null,
      permissions: json['permissions'] != null
          ? (json['permissions'] as List).cast<String>()
          : const [],
      isManager: json['is_manager'] == 1 || json['is_manager'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'initials': initials,
        'employment_status': employmentStatus,
        'name_en': nameEn,
        'email': email,
        'phone': phone,
        'mobile': mobile,
        'address': address,
        'photo_url': photoUrl,
        'job_title': jobTitle,
        'hire_date': hireDate,
        'gender': gender,
        'nationality': nationality,
        'date_of_birth': dateOfBirth,
        'id_number': idNumber,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
        'department': department?.toJson(),
        'company': company?.toJson(),
        'manager': manager?.toJson(),
        'contract': contract?.toJson(),
        'permissions': permissions,
        'is_manager': isManager,
      };

  @override
  List<Object?> get props => [id, code];
}

// ═══════════════════════════════════════════════════════════════════
// Nested Objects
// ═══════════════════════════════════════════════════════════════════

/// `{id: int, name: string, name_en: string?}`
class ProfileDepartment extends Equatable {
  final int id;
  final String name;
  final String? nameEn;

  const ProfileDepartment({
    required this.id,
    required this.name,
    this.nameEn,
  });

  factory ProfileDepartment.fromJson(Map<String, dynamic> json) {
    return ProfileDepartment(
      id: json['id'] as int,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_en': nameEn,
      };

  @override
  List<Object?> get props => [id];
}

/// `{id: int, name: string, company_code: string?}`
class ProfileCompany extends Equatable {
  final int id;
  final String name;
  final String? companyCode;

  const ProfileCompany({
    required this.id,
    required this.name,
    this.companyCode,
  });

  factory ProfileCompany.fromJson(Map<String, dynamic> json) {
    return ProfileCompany(
      id: json['id'] as int,
      name: json['name'] ?? 'N/A',
      companyCode: json['company_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'company_code': companyCode,
      };

  @override
  List<Object?> get props => [id];
}

/// `{id: int, code: string, name: string, job_title: string?}`
class ProfileManager extends Equatable {
  final int id;
  final String code;
  final String name;
  final String? jobTitle;

  const ProfileManager({
    required this.id,
    required this.code,
    required this.name,
    this.jobTitle,
  });

  factory ProfileManager.fromJson(Map<String, dynamic> json) {
    return ProfileManager(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      jobTitle: json['job_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'job_title': jobTitle,
      };

  @override
  List<Object?> get props => [id];
}

/// `{id: int, type: string?, start_date: date?, end_date: date?, status: string}`
class ProfileContract extends Equatable {
  final int id;
  final String? type;
  final String? startDate;  // Y-m-d
  final String? endDate;    // Y-m-d
  final String status;

  const ProfileContract({
    required this.id,
    this.type,
    this.startDate,
    this.endDate,
    required this.status,
  });

  factory ProfileContract.fromJson(Map<String, dynamic> json) {
    return ProfileContract(
      id: json['id'] as int,
      type: json['type'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      };

  @override
  List<Object?> get props => [id];
}
