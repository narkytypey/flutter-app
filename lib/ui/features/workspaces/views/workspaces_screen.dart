import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/icon_tap.dart';

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
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  IconTap(
                    glyph: AppGlyph.back,
                    label: 'Back',
                    onTap: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Workspaces', style: T.screenTitle)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (items.isNotEmpty)
                    Group(
                      children: [
                        for (final item in items)
                          _WorkspaceRow(
                            item: item,
                            onTap: () => onOpen(item.id),
                            onLongPress: onDelete == null
                                ? null
                                : () => onDelete!(item.id),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      // The whole row, not only its glyphs.
                      behavior: HitTestBehavior.opaque,
                      onTap: onNewWorkspace,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            AppIcon(AppGlyph.plus, size: 18, color: C.jade),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text('New workspace',
                                  style: T.label.copyWith(color: C.jade)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                    child: Text(
                      'The same site can live in more than one workspace. Each copy has '
                      'its own login and its own history.',
                      style: T.sub,
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
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            WorkspaceMarker(index: item.markerIndex),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.name, style: T.rowTitle),
                  const SizedBox(height: 2),
                  Text(item.statsLine, style: T.sub),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon(AppGlyph.forward, size: 18, color: C.chevron),
          ],
        ),
      ),
    );
  }
}

/// A workspace's marker (restyle v2 §2.6): data, not identity, and never
/// jade, so it is not mistaken for a live light.
class WorkspaceMarker extends StatelessWidget {
  const WorkspaceMarker({super.key, required this.index, this.size = 10});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.markers[index],
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
