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

  /// JSON-encoded approval flags from login (`approvals` field).
  ///
  /// Persisted because the `/auth/me` endpoint may not include this block
  /// on every backend version — without persistence, restoring a session
  /// would silently drop the flags and hide the Approvals UI.
  static const String approvalsFlags = 'approvals_flags';

  /// JSON-encoded managed-companies list from login.
  static const String managedCompanies = 'managed_companies';

  /// `task_company_filter_id` — optional int id as string, or "all" / empty = no param.
  static const String companyListFilterId = 'task_company_filter_id';

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

  /// Persisted default currency id for financial employee requests.
  ///
  /// Stores the integer id of a currency (as a string) from `/api/v1/currencies`.
  /// If absent the user has not set a default yet and the currency field in
  /// "New request" will be empty.
  static const String defaultCurrencyId = 'default_currency_id';
}
