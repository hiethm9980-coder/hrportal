import 'package:flutter/material.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import '../providers/my_tasks_provider.dart';

/// The values returned by the advanced filter sheet. A `null` return value
/// means the user dismissed the sheet without tapping Apply.
class AdvancedFilterValues {
  final String? priorityCode;
  final bool overdueOnly;
  final bool openOnly;
  final String? dueFrom; // yyyy-MM-dd
  final String? dueTo;

  const AdvancedFilterValues({
    this.priorityCode,
    this.overdueOnly = false,
    this.openOnly = false,
    this.dueFrom,
    this.dueTo,
  });
}

Future<AdvancedFilterValues?> showAdvancedFilterSheet(
  BuildContext context, {
  required TaskFilter current,
}) {
  return showModalBottomSheet<AdvancedFilterValues>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdvancedFilterSheet(current: current),
  );
}

class _AdvancedFilterSheet extends StatefulWidget {
  final TaskFilter current;
  const _AdvancedFilterSheet({required this.current});

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late String? _priority;
  late bool _overdueOnly;
  late bool _openOnly;
  DateTime? _from;
  DateTime? _to;

  static const _priorities = [
    _PriorityDef('LOW', 'Low', Color(0xFF6B7280)),
    _PriorityDef('MEDIUM', 'Medium', Color(0xFF2563EB)),
    _PriorityDef('HIGH', 'High', Color(0xFFF59E0B)),
    _PriorityDef('CRITICAL', 'Critical', Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _priority = widget.current.priorityCode;
    _overdueOnly = widget.current.overdueOnly;
    _openOnly = widget.current.openOnly;
    _from = _tryParse(widget.current.dueFrom);
    _to = _tryParse(widget.current.dueTo);
  }

  DateTime? _tryParse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.gray300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: AppColors.primaryMid, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Filters'.tr(context),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Priority ──────────────────────────────────────────
                _SectionLabel(text: 'Priority'.tr(context)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _priorities.map((p) {
                    final selected = _priority == p.code;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _priority = selected ? null : p.code;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? p.color
                              : p.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? p.color
                                : p.color.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          p.labelKey.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : p.color,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Overdue / Open ───────────────────────────────────
                _ToggleTile(
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.error,
                  label: 'Overdue only'.tr(context),
                  value: _overdueOnly,
                  onChanged: (v) => setState(() => _overdueOnly = v),
                ),
                const SizedBox(height: 6),
                _ToggleTile(
                  icon: Icons.lock_open_rounded,
                  iconColor: AppColors.success,
                  label: 'Open only'.tr(context),
                  value: _openOnly,
                  onChanged: (v) => setState(() => _openOnly = v),
                ),
                const SizedBox(height: 18),

                // ── Date range ───────────────────────────────────────
                _SectionLabel(text: 'Due date'.tr(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Due from'.tr(context),
                        value: _from,
                        onPick: () async {
                          final picked = await _pickDate(context, _from);
                          if (picked != null) setState(() => _from = picked);
                        },
                        onClear: () => setState(() => _from = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateField(
                        label: 'Due to'.tr(context),
                        value: _to,
                        onPick: () async {
                          final picked = await _pickDate(context, _to);
                          if (picked != null) setState(() => _to = picked);
                        },
                        onClear: () => setState(() => _to = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Actions ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: colors.gray300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(const AdvancedFilterValues());
                        },
                        child: Text(
                          'Clear filters'.tr(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            AdvancedFilterValues(
                              priorityCode: _priority,
                              overdueOnly: _overdueOnly,
                              openOnly: _openOnly,
                              dueFrom: _from != null ? _fmtDate(_from!) : null,
                              dueTo: _to != null ? _fmtDate(_to!) : null,
                            ),
                          );
                        },
                        child: Text(
                          'Apply'.tr(context),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
  }
}

class _PriorityDef {
  final String code;
  final String labelKey;
  final Color color;
  const _PriorityDef(this.code, this.labelKey, this.color);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: context.appColors.textSecondary,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.gray200),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primaryMid,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.gray200),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 16, color: AppColors.primaryMid),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null ? _fmt(value!) : '—',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value != null
                          ? colors.textPrimary
                          : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.clear_rounded,
                    size: 16, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
