import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';

/// عُقد التواريخ في التطبيق (مهم لاتّساق العرض وطلبات الـ API):
///
/// **من السيرفر → العرض**
/// - يُفترض أن الطوابع الزمنية تأتي بصيغة ISO-8601 في **UTC** (مفضّل أن ينتهي بـ `Z`).
/// - استخدم [parseInstantFromApi] ثم [formatDate] / [formatDateTime]، أو مباشرة
///   [formatDateFromApi] / [formatDateTimeFromApi] / [formatApiDateTime].
/// - دوال [formatDate], [formatTime], [formatDateTime], [formatMonthYear] تمرّر
///   القيمة عبر [_forDisplay]، فإن مرّرت [DateTime] بـ `isUtc == true` تُحوَّل
///   تلقائياً إلى **منطقة هاتف المستخدم** قبل التنسيق.
///
/// **من التطبيق → السيرفر**
/// - لطوابع **كاملة** (تاريخ + وقت): استخدم [toUtcIso8601ForApi] بعد اختيار القيمة من
///   DatePicker/TimePicker في المنطقة المحلية؛ الناتج ISO بـ `Z` (UTC) كما يتوقعه السيرفر.
/// - لحقول **يوم فقط** بصيغة `yyyy-MM-dd` (بدون وقت في العقد): [toUtcDateOnlyYmdForApi]
///   يُكوّن التاريخ من تقويم المستخدم المحلي (بدون إضافة وقت) — إن طلب الباك أسلوباً
///   آخر (مثلاً يوم UTC) عدّل في موقع الإرسال فقط.
///
/// **تواريخ بلا وقت** (`"2026-05-20"` فقط): تُعرض عادة كما هي أو عبر [formatDate]
/// بعد [DateTime.parse]؛ لا يوجد تحويل منطقة زمنية معنياً إن لم يُذكر وقت.

class AppFuns {
  static String replaceArabicNumbers(String input, {withPeriods = false}) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      input = input.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    if (withPeriods) {
      input = input.replaceAll('ص', 'AM');
      input = input.replaceAll('م', 'PM');
    }
    return input;
  }

  static void hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// يحوّل أي قيمة (bool/String/num) إلى bool بشكل موحّد
  static bool toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'ok') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    }
    return false;
  }

  static Future<void> openUrl(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok) {
      throw Exception('Could not open link');
    }
  }

  /// لعرض واجهة المستخدم: إن كانت اللحظة مخزّنة كـ UTC حوّلها إلى المنطقة المحلية للجهاز.
  static DateTime _forDisplay(DateTime d) => d.isUtc ? d.toLocal() : d;

  /// يفسّر نص ISO من الـ API (مثلاً `2026-01-15T10:00:00.000000Z`) ويعيد [DateTime]
  /// بمنطقة الجهاز المحلية لنفس اللحظة الفورية.
  static DateTime? parseInstantFromApi(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    try {
      final dt = DateTime.parse(iso.trim());
      return dt.isUtc ? dt.toLocal() : dt;
    } catch (_) {
      return null;
    }
  }

  /// يوم تقويم محلي → `yyyy-MM-dd` للأجسام التي يتوقع السيرفر فيها تاريخاً بدون وقت.
  static String toUtcDateOnlyYmdForApi(DateTime localCalendarDay) {
    final d = localCalendarDay;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// طابع محلي من المستخدم → سلسلة ISO-8601 **UTC** للإرسال للـ API.
  static String toUtcIso8601ForApi(DateTime local) {
    return local.toUtc().toIso8601String();
  }

  /// تنسيق تاريخ للعرض: مثلاً **الأربعاء، 20 مايو 2026** (حسب لغة التطبيق/intl).
  static String formatDate(DateTime? d, {withDay = true}) {
    if (d == null) return '';
    final x = _forDisplay(d);
    return replaceArabicNumbers(
      Jiffy.parseFromDateTime(x).format(pattern: withDay ? 'EEEE، d MMMM yyyy' : 'd-MMMM-yyyy'),
    );
  }

  /// نص ISO من السيرفر → نفس نمط [formatDate] بعد التحويل للمحلي.
  static String formatDateFromApi(String? iso, {bool withDay = true}) {
    final dt = parseInstantFromApi(iso);
    if (dt == null) return '';
    return formatDate(dt, withDay: withDay);
  }

  /// "أبريل 2026" — اسم الشهر باللغة الحالية + السنة بأرقام إنجليزية.
  static String formatMonthYear(DateTime? d) {
    if (d == null) return '';
    final x = _forDisplay(d);
    return replaceArabicNumbers(
      Jiffy.parseFromDateTime(x).format(pattern: 'MMMM yyyy'),
    );
  }

  /// Resolves a server-relative URL to an absolute one by prefixing the
  /// current API `baseUrl`.
  static String resolveDownloadUrl(String? path) {
    final p = (path ?? '').trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final base = ApiConstants.baseUrl;
    if (base.isEmpty) return p;
    final trimmedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final trimmedPath = p.startsWith('/') ? p : '/$p';
    return '$trimmedBase$trimmedPath';
  }

  static String formatTime(DateTime? d, {withPeriods = true}) {
    if (d == null) return '';
    final x = _forDisplay(d);
    return replaceArabicNumbers(
      Jiffy.parseFromDateTime(x).format(pattern: withPeriods ? 'h:mm a' : 'H:mm'),
    );
  }

  static String formatDateTime(DateTime? d, {withDay = true, withPeriods = true}) {
    if (d == null) return '';
    final x = _forDisplay(d);
    if (withDay && withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(x).format(pattern: 'EEEE، d MMMM yyyy hh:mm a'),
      );
    } else if (withDay && !withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(x).format(pattern: 'd-MMMM-yyyy H:mm'),
      );
    } else if (!withDay && withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(x).format(pattern: 'hh:mm a'),
      );
    } else if (!withDay && !withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(x).format(pattern: 'H:mm'),
      );
    } else {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(x).format(pattern: 'EEEE، d MMMM yyyy hh:mm a'),
      );
    }
  }

  static String formatDateTimeFromApi(String? iso, {withDay = true, withPeriods = true}) {
    final dt = parseInstantFromApi(iso);
    if (dt == null) return '';
    return formatDateTime(dt, withDay: withDay, withPeriods: withPeriods);
  }

  /// نص UTC من الـ API → عرض بنفس نمط [formatDateTime] (مع خيار إظهار الثواني).
  static String formatApiDateTime(
    String dateStr, {
    bool withSeconds = false,
  }) {
    final local = parseInstantFromApi(dateStr);
    if (local == null) {
      try {
        return replaceArabicNumbers(dateStr);
      } catch (_) {
        return dateStr;
      }
    }
    if (withSeconds) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(local).format(
          pattern: 'EEEE، d MMMM yyyy hh:mm:ss a',
        ),
      );
    }
    return formatDateTime(local, withDay: true, withPeriods: true);
  }
}
