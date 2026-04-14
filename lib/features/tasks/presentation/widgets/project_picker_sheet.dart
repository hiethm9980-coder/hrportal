import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_portal/core/constants/app_colors.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';
import '../../data/models/project_brief_model.dart';
import '../providers/projects_brief_provider.dart';

/// Result of the project picker: either a selected project, the "All projects"
/// sentinel, or a request to open a project's detail page.
class ProjectPickerResult {
  final ProjectBrief? project; // null => "All projects"
  final bool openDetails;

  const ProjectPickerResult._(this.project, this.openDetails);

  factory ProjectPickerResult.all() =>
      const ProjectPickerResult._(null, false);
  factory ProjectPickerResult.select(ProjectBrief p) =>
      ProjectPickerResult._(p, false);
  factory ProjectPickerResult.details(ProjectBrief p) =>
      ProjectPickerResult._(p, true);
}

/// Shows a modal bottom sheet that lets the user pick a project (or "All
/// projects"), with a per-row button to open the project's details page.
Future<ProjectPickerResult?> showProjectPickerSheet(
  BuildContext context, {
  required int? selectedProjectId,
}) {
  return showModalBottomSheet<ProjectPickerResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ProjectPickerSheet(selectedProjectId: selectedProjectId),
  );
}

class _ProjectPickerSheet extends ConsumerWidget {
  final int? selectedProjectId;
  const _ProjectPickerSheet({required this.selectedProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProjects = ref.watch(projectsBriefProvider);
    final colors = context.appColors;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.gray300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.folder_copy_outlined,
                        color: AppColors.primaryMid, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Select project'.tr(context),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        // Invalidate the cached list to force re-fetch.
                        ref.invalidate(projectsBriefProvider);
                      },
                      icon: Icon(Icons.refresh_rounded,
                          color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),
              Expanded(
                child: asyncProjects.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  data: (projects) {
                    // Prepend the "All projects" virtual row.
                    final total = projects.length + 1;
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: total,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: colors.divider),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return _Tile(
                            title: 'All projects'.tr(context),
                            selected: selectedProjectId == null,
                            leading: Icon(
                              Icons.select_all_rounded,
                              color: AppColors.primaryMid,
                            ),
                            onTap: () => Navigator.of(context)
                                .pop(ProjectPickerResult.all()),
                          );
                        }
                        final p = projects[i - 1];
                        return _Tile(
                          title: p.name,
                          subtitle: p.code,
                          selected: selectedProjectId == p.id,
                          leading: const Icon(
                            Icons.folder_outlined,
                            color: AppColors.primaryMid,
                          ),
                          trailing: IconButton(
                            tooltip: 'Project details'.tr(context),
                            icon: const Icon(Icons.info_outline_rounded,
                                color: AppColors.primaryMid),
                            onPressed: () => Navigator.of(context)
                                .pop(ProjectPickerResult.details(p)),
                          ),
                          onTap: () => Navigator.of(context)
                              .pop(ProjectPickerResult.select(p)),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: selected
          ? AppColors.primaryMid.withOpacity(0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? AppColors.primaryMid
                            : colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primaryMid, size: 20),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
