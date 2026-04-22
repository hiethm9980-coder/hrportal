import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import '../../../../data/models/task_models.dart';
import '../../../../data/models/task_priority_model.dart';
import '../../../../data/models/task_status_model.dart';
import '../../../widgets/status_chips_row.dart';

/// Commit callback for the parent task's progress input. Returns a future
/// so the header can await the server round-trip.
typedef ProgressCommitCallback = Future<void> Function(int percent);

/// Header for the Subtasks tab.
///
/// Rows, top-to-bottom:
///   1. Back / title "Subtasks" + parent title subtitle / search toggle /
///      refresh
///   2. Optional search field (AnimatedSize)
///   3. Status breakdown chips (filters subtasks by status)
///   4. Parent status dropdown + Parent progress input + filter button
class SubtasksParentHeader extends StatelessWidget {
  final String parentTitle;
  final Task? parent;
  final List<TaskStatus> allStatuses;
  final StatusBreakdown breakdown;
  final String? selectedStatusCode;
  final bool filtersActive;
  final bool searchActive;
  final bool showSearch;
  final TextEditingController searchController;

  /// Whether the current user is allowed to change the parent task's status.
  /// When false the status dropdown renders as a read-only badge.
  final bool canEditStatus;

  /// Whether the current user is allowed to change the parent task's progress.
  /// When false the progress input renders as a read-only label.
  final bool canEditProgress;

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onToggleSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChipTap;
  final VoidCallback onFilterTap;
  final ValueChanged<TaskStatus> onParentStatusChange;
  final ProgressCommitCallback onParentProgressCommit;

  const SubtasksParentHeader({
    super.key,
    required this.parentTitle,
    required this.parent,
    required this.allStatuses,
    required this.breakdown,
    required this.selectedStatusCode,
    required this.filtersActive,
    required this.searchActive,
    required this.showSearch,
    required this.searchController,
    this.canEditStatus = true,
    this.canEditProgress = true,
    required this.onBack,
    required this.onRefresh,
    required this.onToggleSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
    required this.onStatusChipTap,
    required this.onFilterTap,
    required this.onParentStatusChange,
    required this.onParentProgressCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 14,
        right: 14,
      ),
      child: Column(
        children: [
          _Row1(
            parentTitle: parentTitle,
            parentPriority: parent?.priority,
            showSearch: showSearch,
            searchActive: searchActive,
            onBack: onBack,
            onToggleSearch: onToggleSearch,
            onRefresh: onRefresh,
          ),
          // Search field (animated show/hide).
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: showSearch
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _SearchField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onClear: onClearSearch,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          // Status breakdown chips.
          StatusChipsRow(
            breakdown: breakdown,
            selectedCode: selectedStatusCode,
            onChanged: onStatusChipTap,
          ),
          const SizedBox(height: 10),
          // Parent status dropdown + progress input + filter button.
          _ParentControls(
            parent: parent,
            allStatuses: allStatuses,
            filtersActive: filtersActive,
            canEditStatus: canEditStatus,
            canEditProgress: canEditProgress,
            onParentStatusChange: onParentStatusChange,
            onParentProgressCommit: onParentProgressCommit,
            onFilterTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Row 1 — back / title + subtitle / search toggle / refresh.
// ═══════════════════════════════════════════════════════════════════

class _Row1 extends StatelessWidget {
  final String parentTitle;
  final TaskPriority? parentPriority;
  final bool showSearch;
  final bool searchActive;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;

  const _Row1({
    required this.parentTitle,
    required this.parentPriority,
    required this.showSearch,
    required this.searchActive,
    required this.onBack,
    required this.onToggleSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subtasks'.tr(context),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (parentTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          parentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ),
                      if (parentPriority != null) ...[
                        const SizedBox(width: 6),
                        _PriorityChip(priority: parentPriority!),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        _IconBtn(
          icon: showSearch
              ? Icons.keyboard_arrow_up_rounded
              : Icons.search_rounded,
          active: !showSearch && searchActive,
          onTap: onToggleSearch,
        ),
        const SizedBox(width: 6),
        _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Priority chip — compact pill showing the parent task's priority
// colored by the backend color.
// ═══════════════════════════════════════════════════════════════════

class _PriorityChip extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(priority.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Search field — mirrors the My Tasks header exactly.
// ═══════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Search in subtasks...'.tr(context),
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              suffixIcon: hasText
                  ? GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, left: 4),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Parent controls — status dropdown + progress input + filter button.
// ═══════════════════════════════════════════════════════════════════

class _ParentControls extends StatelessWidget {
  final Task? parent;
  final List<TaskStatus> allStatuses;
  final bool filtersActive;
  final bool canEditStatus;
  final bool canEditProgress;
  final ValueChanged<TaskStatus> onParentStatusChange;
  final ProgressCommitCallback onParentProgressCommit;
  final VoidCallback onFilterTap;

  const _ParentControls({
    required this.parent,
    required this.allStatuses,
    required this.filtersActive,
    required this.canEditStatus,
    required this.canEditProgress,
    required this.onParentStatusChange,
    required this.onParentProgressCommit,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parent status — dropdown when editable, static badge when not.
          Expanded(
            flex: 5,
            child: canEditStatus
                ? _ParentStatusDropdown(
                    current: parent?.status,
                    allStatuses: allStatuses,
                    onChanged: onParentStatusChange,
                  )
                : _ParentStatusBadge(current: parent?.status),
          ),
          const SizedBox(width: 8),
          // Parent progress — editable input or read-only label.
          Expanded(
            flex: 3,
            child: canEditProgress
                ? _ParentProgressInput(
                    initialPercent: parent?.progressPercent ?? 0,
                    onCommit: onParentProgressCommit,
                  )
                : _ParentProgressReadOnly(
                    percent: parent?.progressPercent ?? 0,
                  ),
          ),
          const SizedBox(width: 8),
          // Filter button.
          _FilterButton(active: filtersActive, onTap: onFilterTap),
        ],
      ),
    );
  }
}

// ─────────── Parent status dropdown ───────────

class _ParentStatusDropdown extends StatelessWidget {
  final TaskStatusRef? current;
  final List<TaskStatus> allStatuses;
  final ValueChanged<TaskStatus> onChanged;

  const _ParentStatusDropdown({
    required this.current,
    required this.allStatuses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = current != null ? _parseHex(current!.color) : Colors.white;
    final label = current?.label ?? 'Set status'.tr(context);

    return PopupMenuButton<TaskStatus>(
      enabled: allStatuses.isNotEmpty,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        for (final s in allStatuses)
          PopupMenuItem<TaskStatus>(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parseHex(s.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (current?.code == s.code) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.primaryMid),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                color: Colors.white.withOpacity(0.9)),
          ],
        ),
      ),
    );
  }
}

// ─────────── Parent status badge (read-only fallback) ───────────

class _ParentStatusBadge extends StatelessWidget {
  final TaskStatusRef? current;
  const _ParentStatusBadge({required this.current});

  @override
  Widget build(BuildContext context) {
    final color = current != null ? _parseHex(current!.color) : Colors.white;
    final label = current?.label ?? '—';
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              size: 14, color: Colors.white.withOpacity(0.4)),
        ],
      ),
    );
  }
}

// ─────────── Parent progress input ───────────
//
// A numeric text field capped at 0..100 that commits on blur (focus loss) or
// "done" keyboard action. Used to adjust the parent task's progress without
// requiring a slider in the header (the slider already exists on the card).
class _ParentProgressInput extends StatefulWidget {
  final int initialPercent;
  final ProgressCommitCallback onCommit;

  const _ParentProgressInput({
    required this.initialPercent,
    required this.onCommit,
  });

  @override
  State<_ParentProgressInput> createState() => _ParentProgressInputState();
}

class _ParentProgressInputState extends State<_ParentProgressInput> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late int _committed;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _committed = widget.initialPercent.clamp(0, 100);
    _controller = TextEditingController(text: '$_committed');
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ParentProgressInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect external changes (server reload) only when the user is not
    // actively editing.
    if (!_focus.hasFocus &&
        !_isSaving &&
        widget.initialPercent != _committed) {
      _committed = widget.initialPercent.clamp(0, 100);
      _controller.text = '$_committed';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _submit();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    final parsed = int.tryParse(raw);
    final next = (parsed ?? _committed).clamp(0, 100);
    // Snap the displayed text to the clamped value (handles empty/invalid).
    if (_controller.text != '$next') _controller.text = '$next';

    if (next == _committed) return;

    final previous = _committed;
    setState(() {
      _isSaving = true;
      _committed = next;
    });
    try {
      await widget.onCommit(next);
    } catch (_) {
      // Roll back on failure.
      if (mounted) {
        setState(() {
          _committed = previous;
          _controller.text = '$previous';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.percent_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                hintText: '0',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white54,
                ),
              ),
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Text(
              '%',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────── Parent progress read-only ───────────

class _ParentProgressReadOnly extends StatelessWidget {
  final int percent;
  const _ParentProgressReadOnly({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.percent_rounded, color: Colors.white54, size: 16),
          const SizedBox(width: 4),
          Text(
            '$percent',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '%',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.lock_outline_rounded,
              size: 14, color: Colors.white.withOpacity(0.4)),
        ],
      ),
    );
  }
}

// ─────────── Filter button (gold when advanced filters are active) ───────────

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.gold : Colors.white.withOpacity(0.18),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            if (active)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────── Small round icon button (matches my_tasks_screen look) ───────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─────────── Helpers ───────────

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(withAlpha, radix: 16));
}
