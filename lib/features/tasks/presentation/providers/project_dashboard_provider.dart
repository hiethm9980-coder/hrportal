import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/project_dashboard_model.dart';

/// Loads [ProjectDashboardData] for [projectId]. Auto-disposed when leaving the screen.
final projectDashboardProvider = FutureProvider.autoDispose
    .family<ProjectDashboardData, int>((ref, projectId) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProjectDashboard(projectId);
});
