import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/task_details_model.dart';

/// Whether the signed-in user may edit a time log's **description** only
/// (assignee, project manager, or company manager for the task's company).
bool canEditTimeLogDescription({
  required TaskDetails? details,
  required AuthState auth,
}) {
  final me = auth.employee?.id;
  if (me == null || details == null || details.id == 0) return false;

  final assigneeId = details.assignee?.id ?? details.team.assigneeId;
  if (assigneeId != null && assigneeId == me) return true;

  final pmId = details.project?.manager?.id;
  if (pmId != null && pmId == me) return true;

  final companyId = details.companyId;
  if (companyId != null &&
      (auth.isCompanyManager || auth.managedCompanies.isNotEmpty)) {
    for (final c in auth.managedCompanies) {
      if (c.id == companyId) return true;
    }
  }

  return false;
}
