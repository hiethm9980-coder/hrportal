import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

class SendNotificationFCMService {
  static String? _token;
  static DateTime? _expiry;

  static Future<String> getAccessToken() async {
    final now = DateTime.now();
    final stillValid =
        _token != null &&
        _expiry != null &&
        now.isBefore(_expiry!.subtract(const Duration(minutes: 2)));

    if (stillValid) return _token!;

    final jsonString = await rootBundle.loadString(
      'assets/notifications_key/hr-portal-8317c-144d2c5b9cd8.json',
    );

    final creds = auth.ServiceAccountCredentials.fromJson(jsonString);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(creds, scopes);

    _token = client.credentials.accessToken.data;
    _expiry = client.credentials.accessToken.expiry;
    client.close();

    return _token!;
  }

  Future<void> sendNotificationFCM({
    String? id,

    // ✅ Titles & bodies (AR/EN)
    required String notificationTitleAr,
    required String notificationBodyAr,
    required String notificationTitleEn,
    required String notificationBodyEn,

    // ✅ Image + Route (GetX route)
    String? notificationImage,
    String? notificationRoute,

    // Topics / Token
    bool notificationIsTopics = true,
    required String notificationToWho,

    // Optional extra data
    Map<String, String>? extraData,
  }) async {
    final String accessToken = await getAccessToken();

    debugPrint("accessToken start ==================================");
    debugPrint("accessToken: $accessToken");
    debugPrint("accessToken end ==================================");

    // ✅ مشروعك الصحيح
    final String fcmUrl =
        'https://fcm.googleapis.com/v1/projects/hr-portal-8317c/messages:send';

    // ID تلقائي لو ما أُرسل
    id ??= DateTime.now()
        .toIso8601String()
        .replaceAll("-", "")
        .replaceAll(":", "")
        .replaceAll(".", "");

    // ✅ كل قيم data يجب أن تكون String
    final data = <String, String?>{
      "id": id,
      "title_ar": notificationTitleAr,
      "body_ar": notificationBodyAr,
      "title_en": notificationTitleEn,
      "body_en": notificationBodyEn,
      "image": notificationImage,
      "route": notificationRoute,
      if (extraData != null) ...extraData,
    };

    String priority = (notificationImage == null) ? "high" : "normal";

    // ✅ رسالة Data-only (بدون notification)
    final Map<String, dynamic> message = {
      "data": data,

      // Android: مهم جداً لرسائل data-only
      "android": {"priority": priority},

      // iOS: silent/background (ليس مضمون 100% حسب سياسات iOS)
      "apns": {
        "payload": {
          "aps": {"content-available": 1},
        },
        "headers": {"apns-push-type": "background", "apns-priority": "5"},
      },
    };

    // ✅ topic أو token (مع تنظيف /topics/ لو موجود)
    if (notificationIsTopics == true) {
      final topic = notificationToWho.replaceAll("/topics/", "").trim();
      message["topic"] = topic;
    } else {
      message["token"] = notificationToWho.trim();
    }

    final response = await http.post(
      Uri.parse(fcmUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({"message": message}),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ FCM sent');
    } else {
      debugPrint('❌ FCM failed: ${response.statusCode}');
      debugPrint('Response: ${response.body}');
    }
  }
}
