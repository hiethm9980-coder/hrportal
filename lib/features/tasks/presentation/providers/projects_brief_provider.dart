import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/project_brief_model.dart';
import '../../data/models/project_details_model.dart';
import 'company_list_scope_provider.dart';

/// Provides the list of projects visible to the current user, for the task
/// filters dropdown. Re-fetches when [companyListScopeIdProvider] changes.
final projectsBriefProvider =
    FutureProvider<List<ProjectBrief>>((ref) async {
  final companyId = ref.watch(companyListScopeIdProvider);
  final repo = ref.read(projectRepositoryProvider);
  final data = await repo.listProjects(companyId: companyId);
  return data.projects;
});

/// Fetches a single project's detail envelope (project + permissions).
///
/// Used by [MyTasksScreen] to know whether to show the "Add task" FAB.
/// Family-keyed by project id, autoDispose so it drops out of memory
/// when the user navigates away or clears the project filter.
///
/// The UI treats the `loading` and `error` states as "no FAB" — a safe
/// default since the backend is the source of truth and will still
/// reject unauthorized creates with a clear Arabic error message.
final projectDetailsProvider =
    FutureProvider.autoDispose.family<ProjectDetails, int>((ref, id) async {
  final repo = ref.read(projectRepositoryProvider);
  return repo.getProjectDetails(id);
});
