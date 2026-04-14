import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/task_status_model.dart';

/// Global task statuses provider.
///
/// Cached for the lifetime of the app (no [autoDispose]) because:
/// - Status metadata rarely changes.
/// - Multiple screens (filter chips, status picker, task cards) use it.
///
/// Consume via:
/// ```dart
/// final asyncStatuses = ref.watch(taskStatusesProvider);
/// asyncStatuses.when(
///   data: (list) => ...,
///   loading: () => ...,
///   error: (e, _) => ...,
/// );
/// ```
final taskStatusesProvider =
    FutureProvider<List<TaskStatus>>((ref) async {
  final repo = ref.read(taskRepositoryProvider);
  final data = await repo.getStatuses();
  return data.statuses;
});
