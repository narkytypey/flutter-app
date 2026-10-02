import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

class WorkspaceListItem {
  const WorkspaceListItem({
    required this.id,
    required this.name,
    required this.markerIndex,
    required this.statsLine,
  });

  final String id;
  final String name;
  final int markerIndex;
  final String statsLine;
}

/// Spec `10a` — what each workspace keeps.
class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({
    super.key,
    required this.items,
    required this.onOpen,
    this.onDelete,
    required this.onNewWorkspace,
    required this.onBack,
  });

  final List<WorkspaceListItem> items;
  final void Function(String id) onOpen;

  /// Long-press on a row. Spec `10c` draws the delete confirmation but not
  /// what leads to it; long-press is how a dashboard site row opens its menu.
  final void Function(String id)? onDelete;
  final VoidCallback onNewWorkspace;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹',
                        style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Text('Workspaces', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  for (final item in items)
                    _WorkspaceRow(
                      item: item,
                      onTap: () => onOpen(item.id),
                      onLongPress:
                          onDelete == null ? null : () => onDelete!(item.id),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GestureDetector(
                      // The whole row, not only its glyphs.
                      behavior: HitTestBehavior.opaque,
                      onTap: onNewWorkspace,
                      child: Row(
                        children: [
                          Text('+',
                              style: ui(size: 17, weight: 300, color: C.jade)),
                          const SizedBox(width: 11),
                          Text('New workspace',
                              style:
                                  ui(size: 14.5, weight: 500, color: C.jade)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Text(
                      'The same site can live in more than one workspace. Each copy has '
                      'its own login and its own history.',
                      style: ui(size: 12, height: 1.6, color: C.textDim),
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

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({required this.item, required this.onTap, this.onLongPress});

  final WorkspaceListItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: C.markers[item.markerIndex],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: ui(size: 15, weight: 500)),
                  const SizedBox(height: 4),
                  Text(item.statsLine,
                      style: ui(size: 11.5, color: C.textFaint)),
                ],
              ),
            ),
            Text('›', style: ui(size: 14, color: C.textFaint)),
          ],
        ),
      ),
    );
  }
}
