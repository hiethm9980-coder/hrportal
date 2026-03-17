import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/controllers/global_error_handler.dart';
import '../../data/models/request_models.dart';
import '../providers/request_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// Requests List Screen
// ═══════════════════════════════════════════════════════════════════

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Requests'.tr(context),
            onRefresh: () => ref.read(requestsListProvider.notifier).refresh(),
            leading: GestureDetector(
              onTap: () => context.go('/requests/create'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
          Expanded(
            child: PaginatedListView<EmployeeRequest>(
              state: ref.watch(requestsListProvider),
              onRefresh: () =>
                  ref.read(requestsListProvider.notifier).refresh(),
              onLoadMore: () =>
                  ref.read(requestsListProvider.notifier).loadMore(),
              emptyIcon: Icons.description,
              emptyTitle: 'No requests'.tr(context),
              emptySubtitle: 'Tap + to create a new request'.tr(context),
              itemBuilder: (context, request) =>
                  _RequestTile(request: request),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final EmployeeRequest request;
  const _RequestTile({required this.request});

  String _statusType(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
      case 'processing':
        return 'pending';
      case 'cancelled':
        return 'navy';
      default:
        return 'info';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'salary_certificate':
        return 'Salary certificate';
      case 'experience_letter':
        return 'Experience letter';
      case 'vacation_settlement':
        return 'Vacation settlement';
      case 'loan_request':
        return 'Loan request';
      case 'expense_claim':
        return 'Expense claim';
      case 'training_request':
        return 'Training request';
      case 'other':
        return 'Other';
      default:
        return type ?? 'Request';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatusBadge(
                text: _statusLabel(request.status).tr(context),
                type: _statusType(request.status),
                dot: true,
              ),
              const SizedBox(width: 8),
              Text(
                request.createdAt.substring(0, 10),
                style: GoogleFonts.cairo(
                    fontSize: 11, color: context.appColors.textMuted),
              ),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  request.subject ??
                      _typeLabel(request.requestType).tr(context),
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  _typeLabel(request.requestType).tr(context),
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: context.appColors.textMuted),
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
// Create Request Screen
// ═══════════════════════════════════════════════════════════════════

class CreateRequestScreen extends ConsumerWidget {
  const CreateRequestScreen({super.key});

  static const _types = [
    ('salary_certificate', 'Salary certificate', '📄'),
    ('experience_letter', 'Experience letter', '📝'),
    ('vacation_settlement', 'Vacation settlement', '🌴'),
    ('loan_request', 'Loan request', '💰'),
    ('expense_claim', 'Expense claim', '🧾'),
    ('training_request', 'Training request', '📚'),
    ('other', 'Other', '📋'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(createRequestFormProvider);
    final notifier = ref.read(createRequestFormProvider.notifier);

    ref.listen<CreateRequestFormState>(createRequestFormProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request submitted successfully'.tr(context)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
      if (next.error != null &&
          prev?.error != next.error &&
          next.error!.action != ErrorAction.showFieldErrors) {
        GlobalErrorHandler.show(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: Column(
        children: [
          CustomAppBar(
            title: 'New request'.tr(context),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Type ──
                  Text('Request type *'.tr(context),
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: form.requestType.isEmpty
                        ? null
                        : form.requestType,
                    decoration: InputDecoration(
                        errorText: form.fieldError('request_type')),
                    items: _types
                        .map((t) => DropdownMenuItem(
                              value: t.$1,
                              child: Row(
                                children: [
                                  Text(t.$3,
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(t.$2.tr(context),
                                      style: GoogleFonts.cairo(fontSize: 13)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: form.isLoading
                        ? null
                        : (v) {
                            if (v != null) notifier.setRequestType(v);
                          },
                  ),
                  const SizedBox(height: 14),

                  // ── Subject ──
                  Text('Subject *'.tr(context),
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: notifier.setSubject,
                    enabled: !form.isLoading,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                        errorText: form.fieldError('subject')),
                  ),
                  const SizedBox(height: 14),

                  // ── Description ──
                  Text('Details (optional)'.tr(context),
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: notifier.setDescription,
                    enabled: !form.isLoading,
                    maxLines: 4,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                        errorText: form.fieldError('description')),
                  ),
                ],
              ),
            ),
          ),

          // ── Submit ──
          StickyBottomBar(
            child: PrimaryButton(
              text: 'Submit'.tr(context),
              loading: form.isLoading,
              onTap: form.canSubmit ? notifier.submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
