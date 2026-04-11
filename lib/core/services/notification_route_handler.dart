import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/leave/presentation/screens/leaves_screen.dart';
import '../../features/manager_requests/presentation/screens/manager_requests_screen.dart';
import '../../features/requests/presentation/screens/request_screens.dart';
import '../constants/app_colors.dart';
import '../localization/app_localizations.dart';
import '../providers/core_providers.dart';

/// Parsed notification route.
enum NotificationRouteType {
  approvalLeave,   // /approvals/leaves/{id}
  approvalRequest, // /approvals/requests/{id}
  employeeLeave,   // /leave-requests/{id} or /leaves/{id}
  employeeRequest, // /requests/{id}
}

class ParsedRoute {
  final NotificationRouteType type;
  final int id;
  const ParsedRoute(this.type, this.id);
}

/// Parses a notification route string and returns type + ID, or null.
ParsedRoute? parseNotificationRoute(String route) {
  final path = route.startsWith('/') ? route : '/$route';
  final segments = Uri.parse(path).pathSegments;

  // /approvals/leaves/{id}
  if (segments.length >= 3 &&
      segments[0] == 'approvals' &&
      segments[1] == 'leaves') {
    final id = int.tryParse(segments[2]);
    if (id != null) return ParsedRoute(NotificationRouteType.approvalLeave, id);
  }

  // /approvals/requests/{id}
  if (segments.length >= 3 &&
      segments[0] == 'approvals' &&
      segments[1] == 'requests') {
    final id = int.tryParse(segments[2]);
    if (id != null) return ParsedRoute(NotificationRouteType.approvalRequest, id);
  }

  // /leave-requests/{id}
  if (segments.length >= 2 && segments[0] == 'leave-requests') {
    final id = int.tryParse(segments[1]);
    if (id != null) return ParsedRoute(NotificationRouteType.employeeLeave, id);
  }

  // /leaves/{id} (not /leaves/create)
  if (segments.length >= 2 &&
      segments[0] == 'leaves' &&
      segments[1] != 'create') {
    final id = int.tryParse(segments[1]);
    if (id != null) return ParsedRoute(NotificationRouteType.employeeLeave, id);
  }

  // /requests/{id} (not /requests/create)
  if (segments.length >= 2 &&
      segments[0] == 'requests' &&
      segments[1] != 'create') {
    final id = int.tryParse(segments[1]);
    if (id != null) return ParsedRoute(NotificationRouteType.employeeRequest, id);
  }

  return null;
}

/// Handles a notification route by fetching the data and showing the
/// appropriate bottomsheet. Shows a loading indicator while fetching.
/// Returns true if handled successfully.
Future<bool> handleNotificationRoute({
  required BuildContext context,
  required WidgetRef ref,
  required String route,
}) async {
  final parsed = parseNotificationRoute(route);
  if (parsed == null) return false;

  // Show loading overlay on root navigator (same level as dialog default).
  // IMPORTANT: use rootNavigator so pop() targets the correct overlay.
  final rootNav = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black26,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    switch (parsed.type) {
      case NotificationRouteType.approvalLeave:
        final repo = ref.read(managerLeaveRepositoryProvider);
        final leave = await repo.getLeaveDetail(parsed.id);
        rootNav.pop(); // dismiss loading via root navigator
        if (context.mounted) {
          showManagerLeaveDetailSheet(context, leave);
        }
        return true;

      case NotificationRouteType.approvalRequest:
        final repo = ref.read(managerRequestRepositoryProvider);
        final request = await repo.getRequestDetail(parsed.id);
        rootNav.pop();
        if (context.mounted) {
          showManagerRequestDetailSheet(context, request);
        }
        return true;

      case NotificationRouteType.employeeLeave:
        final repo = ref.read(leaveRepositoryProvider);
        final leave = await repo.getLeaveDetail(parsed.id);
        rootNav.pop();
        if (context.mounted) {
          showEmployeeLeaveDetailSheet(context, leave);
        }
        return true;

      case NotificationRouteType.employeeRequest:
        final repo = ref.read(requestRepositoryProvider);
        final request = await repo.getRequestDetail(parsed.id);
        rootNav.pop();
        if (context.mounted) {
          showEmployeeRequestDetailSheet(context, request);
        }
        return true;
    }
  } catch (_) {
    rootNav.pop(); // dismiss loading
    if (context.mounted) {
      _showNotFoundDialog(context);
    }
    return false;
  }
}

/// Shows a dialog informing the user the item no longer exists.
void _showNotFoundDialog(BuildContext context) {
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.info_outline_rounded,
          size: 48, color: AppColors.warning),
      title: Text(
        'Item not found'.tr(context),
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'This item may have been deleted or is no longer available.'.tr(context),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryMid,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: Text('OK'.tr(context),
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    ),
  );
}
