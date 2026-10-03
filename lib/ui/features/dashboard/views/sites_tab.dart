import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/throwaway.dart';
import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/address_suggestions.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart' show allSitesProvider, sitesChanged;
import '../../settings/view_models/providers.dart' show defaultRouteProvider, searchEngineProvider;
import '../../workspaces/views/workspaces_route.dart' show createWorkspace, editWorkspace;
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'dashboard_footer.dart';
import 'site_row_actions.dart';
import 'workspace_chips.dart';

/// The dashboard's Sites tab (dashboard spec §4.2–§6): workspace chips, the
/// viewed workspace's sites, and the search field, whose suggestions cover
/// the list while it holds text.
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The field holds more than whitespace: its suggestions cover the list.
  bool get _searching => _search.text.trim().isNotEmpty;

  void _endSearch() {
    _search.clear();
    _searchFocus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
    // What typed text is matched against (spec §5), watched from the start so
    // the first keystroke has them. Until the default route is read nothing
    // is offered: a throwaway's tag, and so its route, would be a guess.
    final saved = ref.watch(allSitesProvider).valueOrNull ?? const <Site>[];
    final engine = ref.watch(searchEngineProvider).valueOrNull ?? SearchEngine.duckDuckGo;
    final route = ref.watch(defaultRouteProvider).valueOrNull;
    List<AddressSuggestion> suggest(String text) => route == null
        ? const []
        : suggestionsFor(
            text: text, route: route, saved: saved, workspaces: workspaces, engine: engine);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => PopScope(
        // Plan D7: back while searching clears the field and stays.
        canPop: !_searching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _searching) _endSearch();
        },
        child: DashboardBody(
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
          cover: _searching
              ? AddressSuggestions(
                  suggestions: suggest(_search.text),
                  onPick: (row) => _open(row.destination, view.workspaceId),
                  onDismiss: _endSearch,
                )
              : null,
          footer: DashboardFooter(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            // The address row if there is one, else the search row: the
            // container's address bar makes the same choice.
            onSubmitted: (text) {
              final pick = submittedSuggestion(suggest(text));
              if (pick == null) {
                _endSearch();
              } else {
                _open(pick.destination, view.workspaceId);
              }
            },
            onAddSite: () => _addSite(view.workspaceId),
            emphasise: view.isEmpty,
          ),
        ),
      ),
    );
  }

  /// A suggestion picked, or the keyboard's action (spec §5).
  void _open(Destination destination, String? workspaceId) {
    _endSearch();
    unawaited(_openDestination(destination, workspaceId));
  }

  /// As the container's address bar opens one, with no opener. The
  /// suggestion was worked out from copies of the vault's sites and of the
  /// default route, which can be out of date, so it is decided again here
  /// against both as they are now: a saved site opens with its current route
  /// and profile, never one removed since.
  Future<void> _openDestination(Destination suggested, String? workspaceId) async {
    final saved = await ref.read(siteRepositoryProvider).all();
    final route = await ref.read(defaultRouteProvider.future);
    if (!mounted) return;
    switch (destinationFor(suggested.url, route: route, saved: saved)) {
      case ThisContainer():
        // Only a container's own address bar has one.
        return;
      case SavedSiteContainer(:final site, :final url):
        // As a row opens a site: the visit recorded. Its stored address is
        // not touched.
        openSite(ref, site.id);
        showContainer(context, ref, site, initialUrl: url.toString());
      case final Throwaway target:
        if (workspaceId == null) return;
        // No opener: back from its first page closes it to here (spec §5).
        showContainer(
          context,
          ref,
          buildThrowaway(destination: target, workspaceId: workspaceId, newId: newProfileId),
          throwaway: true,
        );
    }
  }

  /// The `+` (spec §5, §6): a new site's form, on the viewed workspace and
  /// the default route.
  Future<void> _addSite(String? workspaceId) async {
    final workspaces = await ref.read(workspacesProvider.future);
    final route = await ref.read(defaultRouteProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        workspaces: workspaces,
        initialWorkspaceId: workspaceId,
        defaultRoute: route,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          sitesChanged(ref);
          if (formContext.mounted) Navigator.pop(formContext);
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
