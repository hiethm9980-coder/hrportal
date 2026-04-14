import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/project_brief_model.dart';

/// Provides the list of projects visible to the current user, for the task
/// filters dropdown. Cached until invalidated (e.g. by pull-to-refresh).
final projectsBriefProvider =
    FutureProvider<List<ProjectBrief>>((ref) async {
  final repo = ref.read(projectRepositoryProvider);
  final data = await repo.listProjects();
  return data.projects;
});
