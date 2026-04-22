import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/project_team_models.dart';

/// Fetches the team of a single project (manager + members).
///
/// `autoDispose.family` is the right fit — each open Add-Task screen fetches
/// the team for its project once and releases it when the screen closes, so
/// we don't accumulate stale caches as the user hops across projects.
final projectTeamProvider =
    FutureProvider.autoDispose.family<ProjectTeamData, int>((ref, projectId) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.listProjectTeam(projectId);
});
