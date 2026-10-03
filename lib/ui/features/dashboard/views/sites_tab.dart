import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart'
    show allSitesProvider, searchQueryProvider, searchResultsProvider, sitesChanged;
import '../../search/view_models/search_view.dart' show SearchResultEntry;
import '../../search/views/search_screen.dart';
import '../../workspaces/views/workspaces_route.dart' show createWorkspace, editWorkspace;
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'dashboard_footer.dart';
import 'site_row_actions.dart';
import 'workspace_chips.dart';

/// The dashboard's Sites tab (dashboard spec §4.2–§4.4): workspace chips and
/// the viewed workspace's sites.
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => DashboardBody(
        view: view,
        chips: [
          for (final workspace in workspaces)
            WorkspaceChip(
              id: workspace.id,
              name: workspace.name,
              selected: workspace.id == view.workspaceId,
            ),
        ],
        onPickWorkspace: (id) => ref.read(activeWorkspaceIdProvider.notifier).state = id,
        onEditWorkspace: (id) => editWorkspace(context, ref, id),
        onNewWorkspace: () => createWorkspace(context, ref),
        onOpenSite: _openSite,
        onSiteMenu: (siteId) => showSiteRowMenu(context, ref, siteId),
        footer: DashboardFooter(
          onAddSite: _addSite,
          onSearch: () {
            ref.invalidate(searchQueryProvider);
            ref.invalidate(allSitesProvider);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const _SearchRoute()));
          },
          emphasise: view.isEmpty,
        ),
      ),
    );
  }

  Future<void> _addSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddSiteScreen(
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          sitesChanged(ref);
          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    ));
  }

  // Tabs spec §4.2: an open container is shown as it is, with no second open;
  // otherwise it opens. Either way through the one host route.
  Future<void> _openSite(String siteId) async {
    openSite(ref, siteId);
    final site = await ref.read(siteRepositoryProvider).byId(siteId);
    if (site == null || !mounted) return;
    showContainer(context, ref, site);
  }
}

class _SearchRoute extends ConsumerStatefulWidget {
  const _SearchRoute();

  @override
  ConsumerState<_SearchRoute> createState() => _SearchRouteState();
}

class _SearchRouteState extends ConsumerState<_SearchRoute> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return SearchScreen(
      controller: _controller,
      results: results.value ?? const [],
      onQueryChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
      onOpen: (siteId) async {
        final entries = results.value ?? const [];
        SearchResultEntry? entry;
        for (final candidate in entries) {
          if (candidate.siteId == siteId) {
            entry = candidate;
            break;
          }
        }
        if (entry == null) return;
        ref.read(activeWorkspaceIdProvider.notifier).state = entry.workspaceId;
        openSite(ref, siteId);
        final site = await ref.read(siteRepositoryProvider).byId(siteId);
        if (site == null || !context.mounted) return;
        // Pops this search route itself, down to the dashboard.
        showContainer(context, ref, site);
      },
      onBack: () => Navigator.pop(context),
    );
  }
}
