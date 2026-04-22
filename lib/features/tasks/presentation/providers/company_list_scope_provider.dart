import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';

/// Shared [GET /tasks] + [GET /projects] `company_id` (null = API default scope).
///
/// Not part of [TaskFilter] to avoid a circular import with [projectsBriefProvider].
class CompanyListScopeController extends StateNotifier<int?> {
  CompanyListScopeController(this._ref) : super(null);
  final Ref _ref;

  /// Persists the choice; caller should [MyTasksController.load] afterward.
  Future<void> setScope(int? id) async {
    if (state == id) return;
    state = id;
    if (id == null) {
      await _ref.read(secureStorageProvider).saveTaskCompanyListFilterId(null);
    } else {
      await _ref
          .read(secureStorageProvider)
          .saveTaskCompanyListFilterId(id.toString());
    }
  }

  /// Restore from secure storage if the id is still in [allowedIds].
  Future<void> restoreIfAllowed(Set<int> allowedIds) async {
    final storage = _ref.read(secureStorageProvider);
    final raw = await storage.getTaskCompanyListFilterId();
    if (raw == null || raw.isEmpty || raw == 'all') return;
    final id = int.tryParse(raw);
    if (id == null || !allowedIds.contains(id)) {
      await storage.saveTaskCompanyListFilterId(null);
      return;
    }
    if (state == id) return;
    state = id;
  }
}

final companyListScopeIdProvider =
    StateNotifierProvider<CompanyListScopeController, int?>(
  (ref) => CompanyListScopeController(ref),
);
