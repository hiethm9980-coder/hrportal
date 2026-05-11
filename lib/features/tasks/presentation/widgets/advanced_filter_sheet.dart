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
  final bool assigneeOnlyMe;
  /// `name` | `updated_at` | `created_at`. Defaults to `updated_at`.
  final String sortBy;
  /// `asc` | `desc`. Defaults to `desc`.
  final String sortDir;
  /// `roots` (default — root tasks only) | `all` (root + subtasks). Drives
  /// which list endpoint the controller hits.
  final String listScope;

  const AdvancedFilterValues({
    this.priorityCode,
    this.overdueOnly = false,
    this.openOnly = false,
    this.dueFrom,
    this.dueTo,
    this.assigneeOnlyMe = false,
    this.sortBy = TaskFilter.defaultSortBy,
    this.sortDir = TaskFilter.defaultSortDir,
    this.listScope = TaskListScope.defaultScope,
  });
}

/// Bottom sheet for the «advanced» filters (display mode, scope, sort,
/// priority, dates, …).
///
/// - [showSort] hides the Sort dropdown for callers backed by endpoints that
///   don't honour `sort_by`/`sort_dir` (e.g. the subtasks tab).
/// - [showListScope] hides the «Display mode» chips (root only / all) for
///   the same reason — only the root list (`/tasks` + `/tasks/roots`)
///   exposes that switch on the backend.
Future<AdvancedFilterValues?> showAdvancedFilterSheet(
  BuildContext context, {
  required TaskFilter current,
  bool showSort = true,
  bool showListScope = true,
}) {
  return showModalBottomSheet<AdvancedFilterValues>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdvancedFilterSheet(
      current: current,
      showSort: showSort,
      showListScope: showListScope,
    ),
  );
}

class _AdvancedFilterSheet extends StatefulWidget {
  final TaskFilter current;
  final bool showSort;
  final bool showListScope;
  const _AdvancedFilterSheet({
    required this.current,
    required this.showSort,
    required this.showListScope,
  });

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late String? _priority;
  late bool _overdueOnly;
  late bool _openOnly;
  late bool _assigneeOnlyMe;
  late String _sortBy;
  late String _sortDir;
  late String _listScope;
  DateTime? _from;
  DateTime? _to;

  static const _priorities = [
    _PriorityDef('LOW', 'Low', Color(0xFF6B7280)),
    _PriorityDef('MEDIUM', 'Medium', Color(0xFF2563EB)),
    _PriorityDef('HIGH', 'High', Color(0xFFF59E0B)),
    _PriorityDef('CRITICAL', 'Critical', Color(0xFFDC2626)),
  ];

  /// Six concrete sort options displayed in the dropdown. Order matters —
  /// it's the order shown in the menu. Each option carries the labelKey
  /// used for translation + the matching `sort_by`/`sort_dir` pair.
  static const _sortOptions = <_SortOption>[
    _SortOption('Most recently updated', 'updated_at', 'desc'),
    _SortOption('Least recently updated', 'updated_at', 'asc'),
    _SortOption('Newest created', 'created_at', 'desc'),
    _SortOption('Oldest created', 'created_at', 'asc'),
    _SortOption('Name (A-Z)', 'name', 'asc'),
    _SortOption('Name (Z-A)', 'name', 'desc'),
  ];

  /// Picks the option matching the given (sortBy, sortDir) pair. Falls back
  /// to the default (`updated_at`, `desc`) when the pair is unknown — this
  /// keeps the dropdown selection valid even if the backend ever introduces
  /// new sort keys we don't yet render.
  _SortOption _resolveSortOption(String by, String dir) {
    return _sortOptions.firstWhere(
      (o) => o.sortBy == by && o.sortDir == dir,
      orElse: () => _sortOptions.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _priority = widget.current.priorityCode;
    _overdueOnly = widget.current.overdueOnly;
    _openOnly = widget.current.openOnly;
    _assigneeOnlyMe = widget.current.assigneeOnlyMe;
    _sortBy = widget.current.sortBy;
    _sortDir = widget.current.sortDir;
    _listScope = widget.current.listScope;
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
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    // Cap the sheet at 85% of the screen so the user always sees a slice
    // of the page behind it and the header never disappears off-screen on
    // very small devices. The header stays pinned, the filters scroll.
    final maxSheetHeight = media.size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Pinned header (drag handle + title + close) ────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: AppColors.primaryMid,
                                  size: 22,
                                ),
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
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.textSecondary,
                              size: 22,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Scrollable filter body ─────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // ── Display mode: root tasks only vs all tasks ─────────
                if (widget.showListScope) ...[
                  _SectionLabel(text: 'Tasks display mode'.tr(context)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ScopeChipSheet(
                          selected: _listScope == TaskListScope.roots,
                          label: 'Root tasks only'.tr(context),
                          onTap: () => setState(
                            () => _listScope = TaskListScope.roots,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ScopeChipSheet(
                          selected: _listScope == TaskListScope.all,
                          label: 'All tasks'.tr(context),
                          onTap: () => setState(
                            () => _listScope = TaskListScope.all,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                // ── Scope: all relevant vs assignee only ───────────────
                _SectionLabel(text: 'Tasks scope section'.tr(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScopeChipSheet(
                        selected: !_assigneeOnlyMe,
                        label: 'Tasks scope all'.tr(context),
                        onTap: () => setState(() => _assigneeOnlyMe = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ScopeChipSheet(
                        selected: _assigneeOnlyMe,
                        label: 'Tasks scope assignee only'.tr(context),
                        onTap: () => setState(() => _assigneeOnlyMe = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Sort by (above Priority, hidden on subtasks tab) ─
                if (widget.showSort) ...[
                  _SectionLabel(text: 'Sort by'.tr(context)),
                  const SizedBox(height: 8),
                  _SortDropdown(
                    selected: _resolveSortOption(_sortBy, _sortDir),
                    options: _sortOptions,
                    onChanged: (opt) => setState(() {
                      _sortBy = opt.sortBy;
                      _sortDir = opt.sortDir;
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
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
                              assigneeOnlyMe: _assigneeOnlyMe,
                              sortBy: _sortBy,
                              sortDir: _sortDir,
                              listScope: _listScope,
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

class _SortOption {
  /// Translation key (English string) used for `labelKey.tr(context)`.
  final String labelKey;
  final String sortBy;
  final String sortDir;
  const _SortOption(this.labelKey, this.sortBy, this.sortDir);
}

/// Styled dropdown that matches the sheet's other field aesthetics
/// (gray-50 background, rounded 12, light border). Uses native
/// [DropdownButtonHideUnderline] + [DropdownButton] so it picks up the
/// platform's menu treatment automatically and works correctly under RTL.
class _SortDropdown extends StatelessWidget {
  final _SortOption selected;
  final List<_SortOption> options;
  final ValueChanged<_SortOption> onChanged;

  const _SortDropdown({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sort_rounded,
            size: 18,
            color: AppColors.primaryMid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_SortOption>(
                value: selected,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.textMuted,
                ),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                dropdownColor: colors.bgCard,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (final opt in options)
                    DropdownMenuItem<_SortOption>(
                      value: opt,
                      child: Text(opt.labelKey.tr(context)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChipSheet extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _ScopeChipSheet({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMid.withOpacity(0.12) : colors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryMid : colors.gray200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primaryMid : colors.textPrimary,
          ),
        ),
      ),
    );
  }
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
