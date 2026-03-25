/// Secure storage key names.
///
/// These keys are used by [SecureTokenStorage] to persist auth/session data.
class StorageKeys {
  StorageKeys._();

  static const String token = 'access_token';
  static const String employeeId = 'employee_id';
  static const String companyId = 'company_id';

  /// Whether the user is a manager (from login API: is_manager).
  static const String isManager = 'is_manager';

  /// Last used API base URL — used to detect URL changes.
  static const String lastBaseUrl = 'last_base_url';

  /// Persisted user language preference.
  ///
  /// Values are expected to be one of: 'system', 'en', 'ar'.
  static const String locale = 'app_locale';

  /// Persisted theme mode preference.
  ///
  /// Values are expected to be one of: 'system', 'light', 'dark'.
  static const String themeMode = 'app_theme_mode';
}
