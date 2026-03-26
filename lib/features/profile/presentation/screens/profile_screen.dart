import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/errors/exceptions.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/core/providers/core_providers.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMid),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Error loading profile'.tr(context),
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: context.appColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: Text('Retry'.tr(context)),
              ),
            ],
          ),
        ),
        data: (profile) => CustomScrollView(
          slivers: [
            // ── Hero Header ──
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryMid, AppColors.primaryDeep],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 28,
                  left: 18,
                  right: 18,
                ),
                child: Column(
                  children: [
                    // ── Top row: back + title ──
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Profile'.tr(context),
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Avatar + Info row ──
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.goldLight,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: profile.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    profile.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        profile.initials,
                                        style: GoogleFonts.cairo(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    profile.initials,
                                    style: GoogleFonts.cairo(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        // Name + Job title + Code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: GoogleFonts.cairo(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (profile.jobTitle != null)
                                Text(
                                  profile.jobTitle!,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.goldLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  profile.code,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Change Password ──
                  const _ChangePasswordSection(),
                  const SizedBox(height: 12),

                  // ── Personal Info ──
                  _SectionCard(
                    title: 'Personal information'.tr(context),
                    icon: Icons.person_outline_rounded,
                    children: [
                      if (profile.email != null)
                        _InfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email'.tr(context),
                          value: profile.email!,
                        ),
                      if (profile.mobile != null)
                        _InfoTile(
                          icon: Icons.phone_android_rounded,
                          label: 'Mobile'.tr(context),
                          value: profile.mobile!,
                        ),
                      if (profile.phone != null)
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone'.tr(context),
                          value: profile.phone!,
                        ),
                      if (profile.gender != null)
                        _InfoTile(
                          icon: Icons.wc_rounded,
                          label: 'Gender'.tr(context),
                          value: profile.gender == 'male'
                              ? 'Male'.tr(context)
                              : 'Female'.tr(context),
                        ),
                      if (profile.dateOfBirth != null)
                        _InfoTile(
                          icon: Icons.cake_outlined,
                          label: 'Date of birth'.tr(context),
                          value: profile.dateOfBirth!,
                        ),
                      if (profile.nationality != null)
                        _InfoTile(
                          icon: Icons.flag_outlined,
                          label: 'Nationality'.tr(context),
                          value: profile.nationality!,
                        ),
                      if (profile.idNumber != null)
                        _InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'ID number'.tr(context),
                          value: profile.idNumber!,
                        ),
                      if (profile.address != null)
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Address'.tr(context),
                          value: profile.address!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Work Info ──
                  _SectionCard(
                    title: 'Work information'.tr(context),
                    icon: Icons.work_outline_rounded,
                    children: [
                      if (profile.department != null)
                        _InfoTile(
                          icon: Icons.business_rounded,
                          label: 'Department'.tr(context),
                          value: profile.department!.name,
                        ),
                      if (profile.company != null)
                        _InfoTile(
                          icon: Icons.apartment_rounded,
                          label: 'Company'.tr(context),
                          value: profile.company!.name,
                        ),
                      _InfoTile(
                        icon: Icons.badge_rounded,
                        label: 'Employment status'.tr(context),
                        value: _employmentStatusLabel(
                            context, profile.employmentStatus),
                      ),
                      if (profile.hireDate != null)
                        _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Hire date'.tr(context),
                          value: profile.hireDate!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Manager Info ──
                  if (profile.manager != null)
                    _SectionCard(
                      title: 'Direct manager'.tr(context),
                      icon: Icons.supervisor_account_outlined,
                      children: [
                        _InfoTile(
                          icon: Icons.person_rounded,
                          label: 'Name'.tr(context),
                          value: profile.manager!.name,
                        ),
                        if (profile.manager!.jobTitle != null)
                          _InfoTile(
                            icon: Icons.work_rounded,
                            label: 'Job title'.tr(context),
                            value: profile.manager!.jobTitle!,
                          ),
                      ],
                    ),
                  if (profile.manager != null) const SizedBox(height: 12),

                  // ── Emergency Contact ──
                  if (profile.emergencyContactName != null ||
                      profile.emergencyContactPhone != null)
                    _SectionCard(
                      title: 'Emergency contact'.tr(context),
                      icon: Icons.emergency_outlined,
                      children: [
                        if (profile.emergencyContactName != null)
                          _InfoTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Name'.tr(context),
                            value: profile.emergencyContactName!,
                          ),
                        if (profile.emergencyContactPhone != null)
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'Phone'.tr(context),
                            value: profile.emergencyContactPhone!,
                          ),
                      ],
                    ),

                  // ── Contract ──
                  if (profile.contract != null) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Contract'.tr(context),
                      icon: Icons.description_outlined,
                      children: [
                        if (profile.contract!.type != null)
                          _InfoTile(
                            icon: Icons.category_outlined,
                            label: 'Type'.tr(context),
                            value: profile.contract!.type!,
                          ),
                        _InfoTile(
                          icon: Icons.info_outline_rounded,
                          label: 'Status'.tr(context),
                          value: profile.contract!.status,
                        ),
                        if (profile.contract!.startDate != null)
                          _InfoTile(
                            icon: Icons.play_arrow_rounded,
                            label: 'From'.tr(context),
                            value: profile.contract!.startDate!,
                          ),
                        if (profile.contract!.endDate != null)
                          _InfoTile(
                            icon: Icons.stop_rounded,
                            label: 'To'.tr(context),
                            value: profile.contract!.endDate!,
                          ),
                      ],
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _employmentStatusLabel(BuildContext context, String status) {
    switch (status) {
      case 'core_employee':
        return 'Core employee'.tr(context);
      case 'contractor':
        return 'Contractor'.tr(context);
      case 'intern':
        return 'Intern'.tr(context);
      case 'part_time':
        return 'Part time'.tr(context);
      default:
        return status;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Section Card
// ═══════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primaryMid),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // ── Items ──
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Info Tile
// ═══════════════════════════════════════════════════════════════════

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.appColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Change Password Section
// ═══════════════════════════════════════════════════════════════════

class _ChangePasswordSection extends ConsumerStatefulWidget {
  const _ChangePasswordSection();

  @override
  ConsumerState<_ChangePasswordSection> createState() =>
      _ChangePasswordSectionState();
}

class _ChangePasswordSectionState
    extends ConsumerState<_ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final message = await authRepo.changePassword(
        currentPassword: _currentCtrl.text.trim(),
        newPassword: _newCtrl.text.trim(),
        confirmPassword: _confirmCtrl.text.trim(),
      );

      if (!mounted) return;

      // Show success then logout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );

      // Logout and go to login
      ref.read(authProvider.notifier).onLogout();
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.warning),
          ),
          title: Text(
            'Change password'.tr(context),
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
          ),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Current password
                  _PasswordField(
                    controller: _currentCtrl,
                    label: 'Current password'.tr(context),
                    obscure: _obscureCurrent,
                    onToggle: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'This field is required'.tr(context);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // New password
                  _PasswordField(
                    controller: _newCtrl,
                    label: 'New password'.tr(context),
                    obscure: _obscureNew,
                    onToggle: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'This field is required'.tr(context);
                      }
                      if (v.trim().length < 8) {
                        return 'Password must be at least 8 characters'
                            .tr(context);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Confirm password
                  _PasswordField(
                    controller: _confirmCtrl,
                    label: 'Confirm password'.tr(context),
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'This field is required'.tr(context);
                      }
                      if (v.trim() != _newCtrl.text.trim()) {
                        return 'Passwords do not match'.tr(context);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primaryMid,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Change password'.tr(context),
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.cairo(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(
            fontSize: 13, color: context.appColors.textMuted),
        filled: true,
        fillColor: context.appColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryMid, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: context.appColors.textMuted,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
