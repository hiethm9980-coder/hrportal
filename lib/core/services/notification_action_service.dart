// notification_action_service.dart
//
// Handles approve/reject actions triggered from notification buttons.
// Works in foreground, background, AND terminated states because it
// uses only dart:io HttpClient + FlutterSecureStorage (no Riverpod/Dio).

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Result of an approval action performed from a notification.
class ApprovalActionResult {
  final bool success;
  final String? message;
  const ApprovalActionResult({required this.success, this.message});
}

/// Parses a route like `/approvals/leaves/5` or `/approvals/requests/20`
/// and returns the resource type and id.
class _ParsedApprovalRoute {
  /// `leaves` or `requests`
  final String resource;
  final int id;
  const _ParsedApprovalRoute({required this.resource, required this.id});
}

class NotificationActionService {
  NotificationActionService._();

  /// Whether the given route represents a manager approval notification.
  static bool isApprovalRoute(String? route) {
    if (route == null || route.isEmpty) return false;
    return route.contains('/approvals/');
  }

  /// Execute an approval decision from a notification action.
  ///
  /// [route]    — e.g. `/approvals/leaves/5`
  /// [decision] — `approved` or `rejected`
  /// [notes]    — optional notes text from the reply field
  static Future<ApprovalActionResult> executeDecision({
    required String route,
    required String decision,
    String? notes,
  }) async {
    try {
      final parsed = _parseRoute(route);
      if (parsed == null) {
        return const ApprovalActionResult(
          success: false,
          message: 'Invalid approval route',
        );
      }

      // Read token and baseUrl from secure storage.
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: StorageKeys.token);
      final baseUrl = await storage.read(key: StorageKeys.lastBaseUrl);

      if (token == null || token.isEmpty) {
        return const ApprovalActionResult(
          success: false,
          message: 'No auth token available',
        );
      }
      if (baseUrl == null || baseUrl.isEmpty) {
        return const ApprovalActionResult(
          success: false,
          message: 'No base URL configured',
        );
      }

      // Build the API URL.
      final endpoint = _buildEndpoint(parsed, decision);
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final url = Uri.parse('$cleanBase$endpoint');

      // Build body.
      final body = <String, dynamic>{};
      if (parsed.resource == 'leaves') {
        // Leaves use /decide with status field.
        body['status'] = decision;
      }
      if (notes != null && notes.trim().isNotEmpty) {
        body['notes'] = notes.trim();
      }

      log('[NotifAction] POST $url body=$body');

      // Make the HTTP request using dart:io HttpClient.
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.postUrl(url);
        request.headers.set('Accept', 'application/json');
        request.headers.set('Content-Type', 'application/json; charset=utf-8');
        request.headers.set('Authorization', 'Bearer $token');
        request.add(utf8.encode(jsonEncode(body)));

        final response = await request.close();
        final responseBody =
            await response.transform(utf8.decoder).join();

        log('[NotifAction] Response ${response.statusCode}: $responseBody');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const ApprovalActionResult(success: true);
        } else {
          // Try to extract error message.
          try {
            final json = jsonDecode(responseBody) as Map<String, dynamic>;
            return ApprovalActionResult(
              success: false,
              message: json['message'] as String? ?? 'Error ${response.statusCode}',
            );
          } catch (_) {
            return ApprovalActionResult(
              success: false,
              message: 'Error ${response.statusCode}',
            );
          }
        }
      } finally {
        client.close();
      }
    } catch (e, s) {
      log('[NotifAction] Error: $e', stackTrace: s);
      return ApprovalActionResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Parse route like `/approvals/leaves/5` → resource=leaves, id=5.
  static _ParsedApprovalRoute? _parseRoute(String route) {
    // Expected: /approvals/leaves/{id} or /approvals/requests/{id}
    final regex = RegExp(r'/approvals/(leaves|requests)/(\d+)');
    final match = regex.firstMatch(route);
    if (match == null) return null;
    return _ParsedApprovalRoute(
      resource: match.group(1)!,
      id: int.parse(match.group(2)!),
    );
  }

  /// Build the API endpoint for the decision.
  static String _buildEndpoint(_ParsedApprovalRoute parsed, String decision) {
    final action = decision == 'approved' ? 'approve' : 'reject';

    if (parsed.resource == 'leaves') {
      // Leaves use /decide endpoint with status in body.
      return '/api/v1/approvals/leaves/${parsed.id}/decide';
    } else {
      // Requests use separate /approve and /reject endpoints.
      return '/api/v1/approvals/requests/${parsed.id}/$action';
    }
  }
}
