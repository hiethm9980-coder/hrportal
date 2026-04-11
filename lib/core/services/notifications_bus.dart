import 'dart:async';

/// Lightweight event bus for notification-driven UI refreshes.
///
/// When a foreground FCM message arrives, the service calls
/// [notifyChanged] (badge refresh) and [notifyRouteChanged] (data refresh).
/// Screens listen to [routeStream] to auto-refresh their data when the
/// incoming notification is relevant to the currently visible screen.
class NotificationsBus {
  NotificationsBus._();

  // ── Badge / unread-count stream (existing) ──
  static final _c = StreamController<void>.broadcast();
  static Stream<void> get stream => _c.stream;

  static void notifyChanged() {
    if (!_c.isClosed) _c.add(null);
  }

  // ── Route-based refresh stream ──
  static final _routeController = StreamController<String>.broadcast();

  /// Emits the notification `route` so screens can auto-refresh when the
  /// incoming notification is relevant (e.g. `/approvals/leaves/5`).
  static Stream<String> get routeStream => _routeController.stream;

  /// Call this when a foreground notification arrives with a route.
  static void notifyRouteChanged(String route) {
    if (!_routeController.isClosed) _routeController.add(route);
  }
}
