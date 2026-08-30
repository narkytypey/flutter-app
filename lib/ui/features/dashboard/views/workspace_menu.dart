import 'package:flutter/material.dart';

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
  const WorkspaceMenu({super.key, required this.options, required this.onPick});

  final List<WorkspaceOption> options;
  final void Function(String id) onPick;

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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.name, style: ui(size: 14, weight: 500)),
                            const SizedBox(height: 2),
                            Text(option.meta,
                                style: ui(size: 10, color: C.textFaint)),
                          ],
                        ),
                      ),
                      if (option.selected)
                        const Icon(Icons.check, size: 15, color: C.jade),
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
