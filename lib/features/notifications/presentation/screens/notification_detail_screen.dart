import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';
import 'package:hr_portal/shared/widgets/shared_widgets.dart';

/// صفحة "تفاصيل الإشعار" — تُفتح عند الضغط على إشعار ليس له `route` ولا
/// `url` (لا وجهة للتنقل). تعرض داخل بطاقة واحدة:
///   - التاريخ أعلى البطاقة.
///   - صورة الإشعار بكامل العرض (إن وُجدت).
///   - العنوان بخط عريض.
///   - الجسم كاملاً بدون قصّ، والصفحة كلها قابلة للتمرير عمودياً.
///
/// الجسم نص قابل للتحديد (SelectableText) ليستطيع الموظف نسخ أي جزء
/// (أكواد، أرقام، روابط نصية...).
class NotificationDetailScreen extends StatelessWidget {
  final String title;
  final String body;
  final String date;
  final String? img;

  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.body,
    required this.date,
    this.img,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasImg = img != null && img!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Notification details'.tr(context),
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── التاريخ ──
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        date,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryMid,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── صورة الإشعار (إن وُجدت) ──
                    if (hasImg) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          child: CacheImg(
                            url: img!,
                            boxFit: BoxFit.cover,
                            sizeCircleLoading: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── العنوان (عريض) ──
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryMid,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── الجسم كاملاً (قابل للتحديد والنسخ) ──
                    SelectableText(
                      body,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        height: 1.9,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
