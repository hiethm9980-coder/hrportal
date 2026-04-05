import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/constants/app_shadows.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import 'package:hr_portal/shared/widgets/common_widgets.dart';

import '../../../../core/utils/app_funs.dart';
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

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.appColors.bgCard,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title & Status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10, top: 2),
                    child: Icon(Icons.close,
                        size: 22, color: context.appColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    request.subject ??
                        _typeLabel(request.requestType).tr(context),
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  text: _statusLabel(request.status).tr(context),
                  type: _statusType(request.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Rows ──
            _DetailRow(
              icon: '📋',
              label: 'Type'.tr(context),
              value: _typeLabel(request.requestType).tr(context),
            ),
            _DetailRow(
              icon: '📅',
              label: 'Created at'.tr(context),
              value: AppFuns.formatApiDateTime(request.createdAt, isAr: Localizations.localeOf(context).languageCode == 'ar'),
            ),
            if (request.description != null &&
                request.description!.isNotEmpty)
              _DetailRow(
                icon: '📝',
                label: 'Details'.tr(context),
                value: request.description!,
                multiLine: true,
              ),
            if (request.responseNotes != null &&
                request.responseNotes!.isNotEmpty)
              _DetailRow(
                icon: '💬',
                label: 'Response notes'.tr(context),
                value: request.responseNotes!,
                multiLine: true,
              ),
            if (request.respondedAt != null)
              _DetailRow(
                icon: '⏰',
                label: 'Responded at'.tr(context),
                value: AppFuns.formatApiDateTime(request.respondedAt!, isAr: Localizations.localeOf(context).languageCode == 'ar'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatCreatedDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return AppFuns.formatDate(d);
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = request.subject ??
        _typeLabel(request.requestType).tr(context);
    final typeName = _typeLabel(request.requestType).tr(context);

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Type + Status ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    typeName,
                    style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  text: _statusLabel(request.status).tr(context),
                  type: _statusType(request.status),
                  dot: true,
                ),
              ],
            ),
            // ── Row 2: Subject ──
            if (request.subject != null &&
                request.subject!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subject,
                style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // ── Row 3: Description (max 2 lines) ──
            if (request.description != null &&
                request.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                request.description!,
                style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // ── Row 4: Created at (end-aligned) ──
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                _formatCreatedDate(request.createdAt),
                style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 10,
                  color: context.appColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool multiLine;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: multiLine ? 10 : 1,
                  overflow: TextOverflow.ellipsis,
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
                      style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: form.requestType.isEmpty
                        ? null
                        : form.requestType,
                    decoration: InputDecoration(
                        errorText: form.fieldError('request_type')?.tr(context)),
                    items: _types
                        .map((t) => DropdownMenuItem(
                              value: t.$1,
                              child: Row(
                                children: [
                                  Text(t.$3,
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(t.$2.tr(context),
                                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13)),
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
                  const SizedBox(height: 24),

                  // ── Subject / Amount+Currency ──
                  if (form.isLoanRequest) ...[
                    // Amount field
                    Text('${'Amount'.tr(context)} *',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: notifier.setSubject,
                      enabled: !form.isLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                      decoration: InputDecoration(
                        errorText: form.fieldError('subject')?.tr(context),
                        hintText: 'Enter a positive amount'.tr(context),
                        hintStyle: TextStyle(fontFamily: 'Cairo',
                            fontSize: 13,
                            color: context.appColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Currency dropdown
                    Text('${'Currency'.tr(context)} *',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textSecondary)),
                    const SizedBox(height: 6),
                    _CurrencyDropdown(
                      value: form.currency,
                      enabled: !form.isLoading,
                      onChanged: (v) {
                        if (v != null) notifier.setCurrency(v);
                      },
                    ),
                  ] else ...[
                    Text('Subject *'.tr(context),
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: notifier.setSubject,
                      enabled: !form.isLoading,
                      style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                      decoration: InputDecoration(
                          errorText: form.fieldError('subject')?.tr(context)),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Description ──
                  Text('Details (optional)'.tr(context),
                      style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: notifier.setDescription,
                    enabled: !form.isLoading,
                    maxLines: 4,
                    style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                    decoration: InputDecoration(
                        errorText: form.fieldError('description')?.tr(context)),
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
              onTap: form.isLoading ? null : notifier.submit,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Currency Dropdown
// ═══════════════════════════════════════════════════════════════════

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _CurrencyDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  static const _currencies = [
    ('YER', 'Yemeni Rial', 'ريال يمني'),
    ('USD', 'US Dollar', 'دولار أمريكي'),
    ('SAR', 'Saudi Riyal', 'ريال سعودي'),
  ];

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return DropdownButtonFormField<String>(
      initialValue: value,
      items: _currencies
          .map((c) => DropdownMenuItem(
                value: c.$1,
                child: Text(
                  '${isAr ? c.$3 : c.$2} - ${c.$1}',
                  style: TextStyle(fontFamily: 'Cairo',fontSize: 13),
                ),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
