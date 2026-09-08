import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/widgets/section_label.dart';
import '../view_models/dashboard_view.dart';
import 'dashboard_footer.dart';
import 'empty_workspace.dart';
import 'session_row.dart';
import 'workspace_bar.dart';

/// The dashboard, spec option `1b`. Takes a finished view model and callbacks,
/// so it can be pumped in a widget test with no providers and no database.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.view,
    required this.onWorkspaceTap,
    required this.onAddSite,
    required this.onSearch,
    required this.onOpenSite,
    required this.onSiteMenu,
    required this.onOverflow,
  });

  final DashboardView view;
  final VoidCallback onWorkspaceTap;
  final VoidCallback onAddSite;
  final VoidCallback onSearch;
  final void Function(String siteId) onOpenSite;
  final void Function(String siteId) onSiteMenu;
  final VoidCallback onOverflow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorkspaceBar(
              name: view.workspaceName,
              trailing: view.wipesOnExit
                  ? 'WIPES ON EXIT'
                  : '${view.sessionCount} SESSIONS · ${view.leakCount} LEAKS',
              trailingIsBadge: view.wipesOnExit,
              onTap: onWorkspaceTap,
              onOverflow: onOverflow,
            ),
            Expanded(child: _list()),
            DashboardFooter(
              onAddSite: onAddSite,
              onSearch: onSearch,
              emphasise: view.isEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (view.isEmpty) return const EmptyWorkspace();

    final children = <Widget>[];

    if (view.open.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: SectionLabel('OPEN NOW', live: true),
      ));
      children.addAll(view.open.map(_row));
    }

    if (view.idle.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.fromLTRB(18, 20, 18, 6),
        child: SectionLabel('IDLE'),
      ));
      children.addAll(view.idle.map(_row));
    }

    return ListView(padding: EdgeInsets.zero, children: children);
  }

  Widget _row(SessionEntry entry) => SessionRow(
        key: ValueKey(entry.siteId),
        entry: entry,
        onTap: () => onOpenSite(entry.siteId),
        onLongPress: () => onSiteMenu(entry.siteId),
      );
}
