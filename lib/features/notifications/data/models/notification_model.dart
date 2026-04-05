import 'dart:convert';

class NotificationModel {
  final String id;

  final String titleAr;
  final String bodyAr;

  final String titleEn;
  final String bodyEn;

  final String? img;
  final String? url;
  final String? route;

  /// نخزن نسخة من data كاملة (مثل FCM payload) على شكل Map
  final Map<String, dynamic>? payload;

  /// 0/1 في قاعدة البيانات
  final bool isRead;

  /// epoch millis (مثل: DateTime.now().millisecondsSinceEpoch)
  final int createdAt;

  const NotificationModel({
    required this.id,
    required this.titleAr,
    required this.bodyAr,
    required this.titleEn,
    required this.bodyEn,
    this.img,
    this.url,
    this.route,
    this.payload,
    this.isRead = false,
    required this.createdAt,
  });

  DateTime get createdAtDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt);

  /// اختيار النص حسب اللغة (بدون الاعتماد على Get داخل المودل)
  String titleByLang(String langCode) =>
      (langCode == 'ar') ? (titleAr.isNotEmpty ? titleAr : titleEn) : (titleEn.isNotEmpty ? titleEn : titleAr);

  String bodyByLang(String langCode) =>
      (langCode == 'ar') ? (bodyAr.isNotEmpty ? bodyAr : bodyEn) : (bodyEn.isNotEmpty ? bodyEn : bodyAr);

  // -------------------- DB mapping --------------------

  Map<String, Object?> toDbMap() {
    final map = <String, Object?>{
      'id': id,
      'title_ar': titleAr,
      'body_ar': bodyAr,
      'title_en': titleEn,
      'body_en': bodyEn,
      'img': img,
      'url': url,
      'route': route,
      'payload': payload == null ? null : jsonEncode(payload),
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
    };

    // لا تخزن null
    map.removeWhere((k, v) => v == null);
    return map;
  }

  factory NotificationModel.fromDbMap(Map<String, Object?> row) {
    Map<String, dynamic>? parsedPayload;
    final rawPayload = row['payload'];

    if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map<String, dynamic>) parsedPayload = decoded;
      } catch (_) {}
    }

    int createdAt = 0;
    final ca = row['created_at'];
    if (ca is int) {
      createdAt = ca;
    } else if (ca is BigInt) createdAt = ca.toInt();
    else createdAt = int.tryParse(ca?.toString() ?? '') ?? 0;

    final isReadInt = int.tryParse(row['is_read']?.toString() ?? '0') ?? 0;

    return NotificationModel(
      id: (row['id'] ?? '').toString(),
      titleAr: (row['title_ar'] ?? '').toString(),
      bodyAr: (row['body_ar'] ?? '').toString(),
      titleEn: (row['title_en'] ?? '').toString(),
      bodyEn: (row['body_en'] ?? '').toString(),
      img: row['img']?.toString(),
      url: row['url']?.toString(),
      route: row['route']?.toString(),
      payload: parsedPayload,
      isRead: isReadInt == 1,
      createdAt: createdAt,
    );
  }

  // -------------------- FCM mapping (data-only) --------------------

  factory NotificationModel.fromFcmData(
    Map<String, dynamic> data, {
    String? messageId,
  }) {
    final id = (data['id'] ?? messageId ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

    final createdAt = int.tryParse((data['created_at'] ?? '').toString()) ??
        DateTime.now().millisecondsSinceEpoch;

    final titleEn = (data['title_en'] ?? data['title'] ?? 'Notification').toString();
    final bodyEn  = (data['body_en']  ?? data['body']  ?? '').toString();
    final titleAr = (data['title_ar'] ?? titleEn).toString();
    final bodyAr  = (data['body_ar']  ?? bodyEn).toString();

    return NotificationModel(
      id: id,
      titleAr: titleAr,
      bodyAr: bodyAr,
      titleEn: titleEn,
      bodyEn: bodyEn,
      img: data['image']?.toString() ?? data['img']?.toString(),
      url: data['url']?.toString(),
      route: data['route']?.toString(),
      payload: data,
      isRead: false,
      createdAt: createdAt,
    );
  }
}
