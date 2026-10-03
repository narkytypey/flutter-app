import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../../domain/models/workspace.dart';

class WorkspaceOption {
  const WorkspaceOption({
    required this.id,
    required this.name,
    required this.meta,
    required this.selected,
  });

  final String id;
  final String name;
  final String meta;
  final bool selected;
}

/// A row under the workspaces that leads somewhere else in the app. Spec
/// `5c`: the Today log "is reachable from the dashboard menu".
class ManagementOption {
  const ManagementOption({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// The one-line summary under a workspace's name in the switcher.
String workspaceMeta({
  required Workspace workspace,
  required int siteCount,
  required int openCount,
}) {
  if (workspace.storageRule == StorageRule.wipeOnExit) return 'WIPES ON EXIT';
  return '$siteCount SITES · $openCount OPEN';
}

/// The dropdown that hangs under the workspace name (spec `1a`). It is reused
/// on the `1b` bar, which is why it lives in its own file.
class WorkspaceMenu extends StatelessWidget {
  const WorkspaceMenu({
    super.key,
    required this.options,
    required this.onPick,
    this.managementOptions = const [],
  });

  final List<WorkspaceOption> options;
  final void Function(String id) onPick;
  final List<ManagementOption> managementOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.line08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      // The dashboard stacks this beside its Scaffold, so nothing above it is
      // a Material; the InkWells need one of their own.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              InkWell(
                onTap: () => onPick(option.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: option == options.last
                        ? null
                        : const Border(bottom: BorderSide(color: C.line05)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: ui(size: 14, weight: 500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option.meta,
                                style: ui(size: 10, color: C.textFaint),
                              ),
                            ],
                          ),
                        ),
                        if (option.selected)
                          const AppIcon(
                            AppGlyph.check,
                            size: 15,
                            color: C.jade,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            for (final management in managementOptions)
              InkWell(
                onTap: management.onTap,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: C.line05)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    management.label,
                    style: ui(size: 13, color: C.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
