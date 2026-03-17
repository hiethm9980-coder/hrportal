import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/theme/app_spacing.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/attendance/presentation/screens/attendance_screen.dart';
import '../features/leave/presentation/screens/leaves_screen.dart';
import '../features/leave/presentation/screens/create_leave_screen.dart';
import '../features/payroll/presentation/screens/payroll_screens.dart';
import '../features/requests/presentation/screens/request_screens.dart';

/// Global navigator key for SessionManager callback.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration.
///
/// Auth redirect logic:
/// - If [AuthStatus.unknown] → stay on /splash
/// - If [AuthStatus.unauthenticated] → redirect to /login
/// - If [AuthStatus.authenticated] and on /splash or /login → redirect to /
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,

    redirect: (context, state) {
      final auth = authState;
      final location = state.matchedLocation;

      // Still checking session → stay on splash.
      if (auth.isUnknown) {
        return location == '/splash' ? null : '/splash';
      }

      // Not authenticated → force login.
      if (auth.isUnauthenticated) {
        if (location == '/login') return null;
        return '/login';
      }

      // Authenticated but on splash or login → go home.
      if (auth.isAuthenticated) {
        if (location == '/splash' || location == '/login') return '/';
      }

      return null; // No redirect needed.
    },

    routes: [
      // ── Auth ──
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // ── Main App (with bottom nav shell) ──
      ShellRoute(
        builder: (context, state, child) =>
            _MainShell(state: state, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/attendance',
            builder: (_, __) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/leaves',
            builder: (_, __) => const LeavesScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const CreateLeaveScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, __) => const PayrollScreen(),
            routes: [
              GoRoute(
                path: ':month',
                builder: (_, state) =>
                    PayslipDetailScreen(month: state.pathParameters['month']!),
              ),
            ],
          ),
          GoRoute(
            path: '/requests',
            builder: (_, __) => const RequestsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const CreateRequestScreen(),
              ),
            ],
          ),

          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ═══════════════════════════════════════════════════════════════════
// Main Shell (Bottom Navigation)
// ═══════════════════════════════════════════════════════════════════

class _MainShell extends StatelessWidget {
  final GoRouterState state;
  final Widget child;

  const _MainShell({required this.state, required this.child});

  int get _currentIndex {
    final location = state.matchedLocation;
    if (location.startsWith('/attendance')) return 1;
    if (location.startsWith('/leaves')) return 2;
    if (location.startsWith('/payroll')) return 3;
    if (location.startsWith('/requests')) return 4;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/attendance');
        break;
      case 2:
        context.go('/leaves');
        break;
      case 3:
        context.go('/payroll');
        break;
      case 4:
        context.go('/requests');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppBreakpoints.mobile;
    final isExtended = width >= AppBreakpoints.tablet;

    if (isMobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.appColors.bgCard,
            border: Border(
              top: BorderSide(color: context.appColors.gray100, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _NavItem(
                    icon: '🏠',
                    label: 'Home'.tr(context),
                    active: _currentIndex == 0,
                    onTap: () => _onDestinationSelected(context, 0),
                  ),
                  _NavItem(
                    icon: '⏱',
                    label: 'Attendance'.tr(context),
                    active: _currentIndex == 1,
                    onTap: () => _onDestinationSelected(context, 1),
                  ),
                  _NavItem(
                    icon: '🌴',
                    label: 'Leaves'.tr(context),
                    active: _currentIndex == 2,
                    onTap: () => _onDestinationSelected(context, 2),
                  ),
                  _NavItem(
                    icon: '💰',
                    label: 'Payroll'.tr(context),
                    active: _currentIndex == 3,
                    onTap: () => _onDestinationSelected(context, 3),
                  ),
                  _NavItem(
                    icon: '📝',
                    label: 'Requests'.tr(context),
                    active: _currentIndex == 4,
                    onTap: () => _onDestinationSelected(context, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            extended: isExtended,
            labelType: isExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: Text('Home'.tr(context)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.fingerprint_outlined),
                selectedIcon: const Icon(Icons.fingerprint),
                label: Text('Attendance'.tr(context)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.beach_access_outlined),
                selectedIcon: const Icon(Icons.beach_access),
                label: Text('Leaves'.tr(context)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
                label: Text('Payroll'.tr(context)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description),
                label: Text('Requests'.tr(context)),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.primaryMid : context.appColors.gray400,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primaryMid,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
