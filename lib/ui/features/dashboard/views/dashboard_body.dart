import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/widgets/group.dart';
import '../view_models/dashboard_view.dart';
import 'empty_workspace.dart';
import 'session_row.dart';
import 'workspace_chips.dart';

/// The Sites tab (dashboard spec §4.2–§4.4, replacing `1b`'s layout): the
/// workspace chips, then the viewed workspace's sites as one list with no
/// titles and no count, then [footer]. It takes a finished view model and
/// callbacks, so it can be pumped in a widget test with no providers and no
/// database.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.view,
    required this.chips,
    required this.onPickWorkspace,
    required this.onEditWorkspace,
    required this.onNewWorkspace,
    required this.onOpenSite,
    required this.onSiteMenu,
    required this.footer,
    this.cover,
  });

  final DashboardView view;
  final List<WorkspaceChip> chips;
  final ValueChanged<String> onPickWorkspace;
  final ValueChanged<String> onEditWorkspace;
  final VoidCallback onNewWorkspace;
  final void Function(String siteId) onOpenSite;
  final void Function(String siteId) onSiteMenu;
  final Widget footer;

  /// Shown in the list's place while non-null: the search field's
  /// suggestions (dashboard spec §5). The chips and the footer stay.
  final Widget? cover;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorkspaceChips(
              chips: chips,
              onPick: onPickWorkspace,
              onEdit: onEditWorkspace,
              onNew: onNewWorkspace,
              badge: view.wipesOnExit ? 'WIPES ON EXIT' : null,
            ),
            Expanded(child: cover ?? _list()),
            footer,
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (view.isEmpty) return EmptyWorkspace(wipesOnExit: view.wipesOnExit);
    // Restyle v2 §8 `1b`: the list's rows in one group, soft rules between.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Group(
          padding: EdgeInsets.zero,
          children: [
            for (final entry in view.rows)
              SessionRow(
                key: ValueKey(entry.siteId),
                entry: entry,
                onTap: () => onOpenSite(entry.siteId),
                onLongPress: () => onSiteMenu(entry.siteId),
              ),
          ],
        ),
      ],
    );
  }
}
