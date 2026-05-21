import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/services/notification_fcm/notification_fcm_service.dart';
import 'package:hr_portal/core/storage/secure_token_storage.dart';
import 'package:hr_portal/injection.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../shared/controllers/global_error_handler.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Controller للحقل — مستقل عن LoginFormState لأن FormState تستهلك القيمة
  /// عبر onChanged، لكن إعادة الملء بعد logout تتطلب controller صريح.
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreLastUsername();
  }

  /// يقرأ آخر اسم مستخدم/بريد نجح في تسجيل دخول سابق ويضعه في الحقل
  /// كقيمة افتراضية. لا نُملأ كلمة المرور أبداً (أمان).
  Future<void> _restoreLastUsername() async {
    try {
      final saved = await sl<SecureTokenStorage>().getLastUsername();
      if (!mounted || saved == null || saved.isEmpty) return;
      // إن كان المستخدم قد بدأ بالكتابة قبل أن يصلنا الـ async (نادر جداً
      // لكن ممكن على الويب البطيء)، لا نُكتب فوق ما أدخله.
      if (_usernameController.text.isNotEmpty) return;
      _usernameController.text = saved;
      // مزامنة الحالة في الـ provider حتى يستخدمها submit().
      ref.read(loginFormProvider.notifier).setUsername(saved);
    } catch (_) {
      // فشل القراءة من secure storage لا يجب أن يمنع شاشة الدخول.
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  /// زر تسجيل الدخول → نطلب إذن الإشعارات من المتصفح أولاً (على الويب فقط)
  /// ثم نُكمل تسجيل الدخول. هذا الترتيب مهم لأن المتصفحات تطلب user-gesture
  /// صريحاً لإظهار حوار الإذن — استدعاؤه عند تشغيل التطبيق كان يُحجب على
  /// متصفحات الموبايل. على الموبايل (Android/iOS) الدالة no-op لأن الإذن
  /// يُطلب وقت تشغيل التطبيق.
  Future<void> _handleLogin(LoginFormController notifier) async {
    if (kIsWeb) {
      // لا ننتظر النتيجة قبل تسجيل الدخول — حوار الإذن مستقل عن العملية،
      // والمستخدم قد يختار Block ومع ذلك يدخل التطبيق. النتيجة فقط تتحكم
      // في وصول الإشعارات لاحقاً.
      await NotificationFCMService().requestWebPermissionAndToken();
    }
    await notifier.submit();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(loginFormProvider);
    final notifier = ref.read(loginFormProvider.notifier);

    // Show error snackbar/dialog when error changes.
    ref.listen<LoginFormState>(loginFormProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        if (next.error!.action != ErrorAction.showFieldErrors) {
          GlobalErrorHandler.show(context, next.error!);
        }
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient Header (full width) ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryMid, AppColors.primaryDeep],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 40,
                left: 22,
                right: 22,
              ),
              child: Column(
                children: [
                  // زر الإعدادات في النهاية (RTL-aware عبر Align/end).
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/settings'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Settings'.tr(context),
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome'.tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employee Self Service Portal'.tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Body (centered, max 400px) ──
            Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // ── Username Label ──
                    Text(
                      'Email or username'.tr(context),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _usernameController,
                      onChanged: notifier.setUsername,
                      enabled: !form.isLoading,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Email or username'.tr(context),
                        errorText: form.fieldError('username')?.tr(context),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Password Label ──
                    Text(
                      'Password'.tr(context),
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: notifier.setPassword,
                      enabled: !form.isLoading,
                      obscureText: form.obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                      onSubmitted: (_) {
                        if (form.canSubmit) _handleLogin(notifier);
                      },
                      decoration: InputDecoration(
                        hintText: 'Password'.tr(context),
                        errorText: form.fieldError('password')?.tr(context),
                        suffixIcon: IconButton(
                          onPressed: notifier.togglePasswordVisibility,
                          icon: Icon(
                            form.obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: context.appColors.gray400,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Submit Button ──
                    PrimaryButton(
                      text: 'Login'.tr(context),
                      loading: form.isLoading,
                      onTap: form.isLoading ? null : () => _handleLogin(notifier),
                    ),

                    // ── General Error ──
                    if (form.error != null &&
                        form.error!.action == ErrorAction.showFieldErrors)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            form.error!.message,
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 13,
                              color: AppColors.errorDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

