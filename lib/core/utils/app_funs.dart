import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (v is num) return v != 0; // 1 -> true, 0 -> false
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'ok') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    }
    // قيمة غير معروفة أو null -> اختَر الافتراضي (false)
    return false;
  }


  static Future<void> openUrl(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.inAppBrowserView, // يفتح المتصفح الافتراضي
    );
    if (!ok) {
      throw Exception('Could not open link');
    }
  }

  static String formatDate(DateTime? d, {withDay = true}) {
    if (d == null) return '';
    // Jiffy يعتمد على intl للـ locale
    return replaceArabicNumbers(
      Jiffy.parseFromDateTime(d).format(pattern: withDay ? 'EEEE، d MMMM yyyy' : 'd-MMMM-yyyy'),
    );
  }

  static String formatTime(DateTime? d, {withPeriods = true}) {
    if (d == null) return '';
    return replaceArabicNumbers(
      Jiffy.parseFromDateTime(d).format(pattern: withPeriods ? 'h:mm a' : 'H:mm'),
    );
  }

  static String formatDateTime(DateTime? d, {withDay = true, withPeriods = true}) {
    if (d == null) return '';
    if (withDay && withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'EEEE، d MMMM yyyy | h:mm a' ),
      );
    } else if (withDay && !withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'd-MMMM-yyyy | H:mm' ),
      );
    } else if (!withDay && withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'h:mm a' ),
      );
    } else if (!withDay && !withPeriods) {
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'H:mm' ),
      );
    } else { 
      return replaceArabicNumbers(
        Jiffy.parseFromDateTime(d).format(pattern: 'EEEE، d MMMM yyyy | h:mm a' ),
      );
    }
  }

  /// Formats a UTC date string from API to local datetime.
  /// [withSeconds] includes seconds in the output.
  /// [isAr] uses Arabic period markers (ص/م) instead of AM/PM.
  static String formatApiDateTime(String dateStr, {bool withSeconds = false, bool isAr = false}) {
    try {
      final utc = DateTime.parse(dateStr).toUtc();
      final local = utc.toLocal();
      final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
      final period = local.hour >= 12 ? (isAr ? 'م' : 'PM') : (isAr ? 'ص' : 'AM');
      final dd = local.day.toString().padLeft(2, '0');
      final mm = local.month.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      if (withSeconds) {
        final sec = local.second.toString().padLeft(2, '0');
        return replaceArabicNumbers('$dd-$mm-${local.year} | $h:$min:$sec $period');
      }
      return replaceArabicNumbers('$dd-$mm-${local.year} | $h:$min $period');
    } catch (_) {
      return replaceArabicNumbers(dateStr);
    }
  }
}
