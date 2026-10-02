import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/site_wipe.dart';
import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../container/views/container_route.dart';
import '../../report/views/today_route.dart';
import '../../search/view_models/providers.dart'
    show allSitesProvider, searchQueryProvider, searchResultsProvider, sitesChanged;
import '../../search/view_models/search_view.dart' show SearchResultEntry;
import '../../search/views/search_screen.dart';
import '../../settings/views/settings_route.dart';
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'site_row_menu.dart';
import 'wipe_site_sheet.dart';
import '../views/workspace_menu.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => Stack(
        children: [
          DashboardBody(
            view: view,
            onWorkspaceTap: () => setState(() => _menuOpen = !_menuOpen),
            onAddSite: () async {
              final workspaces = await ref.read(workspacesProvider.future);
              if (!context.mounted) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddSiteScreen(
                  workspaces: workspaces,
                  onSave: (site) async {
                    await ref.read(siteRepositoryProvider).upsert(site);
                    sitesChanged(ref);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
              ));
            },
            onSearch: () {
              ref.invalidate(searchQueryProvider);
              ref.invalidate(allSitesProvider);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const _SearchRoute()));
            },
            onOpenSite: (siteId) async {
              openSite(ref, siteId);
              final site = await ref.read(siteRepositoryProvider).byId(siteId);
              if (site == null || !context.mounted) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ContainerRoute(site: site),
              ));
              ref.invalidate(dashboardProvider);
            },
            onSiteMenu: (siteId) async {
              final site = await ref.read(siteRepositoryProvider).byId(siteId);
              if (site == null || !context.mounted) return;
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => SiteRowMenu(
                  monogram: site.monogram,
                  name: site.name,
                  subtitle: site.url,
                  ephemeralWorkspaceName: 'Ephemeral',
                  duplicateTargetName: 'Work',
                  onCancel: () => Navigator.pop(context),
                  onAction: (action) async {
                    Navigator.pop(context);
                    if (action == SiteRowAction.editSettings) {
                      final workspaces = await ref.read(workspacesProvider.future);
                      if (!context.mounted) return;
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AddSiteScreen(
                          initial: site,
                          workspaces: workspaces,
                          onSave: (updated) async {
                            await ref.read(siteRepositoryProvider).upsert(updated);
                            sitesChanged(ref);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      ));
                    } else if (action == SiteRowAction.removeSite) {
                      // Closed and wiped first: deleting the row alone left
                      // the site's profile and downloads on disk.
                      closeSite(ref, siteId);
                      await removeSavedSite(
                        engine: ref.read(containerEngineProvider),
                        sites: ref.read(siteRepositoryProvider),
                        site: site,
                      );
                      sitesChanged(ref);
                    } else if (action == SiteRowAction.wipeData) {
                      // Asked first (user's ruling, 2026-09-30); the site
                      // stays, under a fresh profile (wipeSavedSite).
                      if (!await confirmWipeSite(context) || !mounted) return;
                      closeSite(ref, siteId);
                      await wipeSavedSite(
                        engine: ref.read(containerEngineProvider),
                        sites: ref.read(siteRepositoryProvider),
                        site: site,
                      );
                      sitesChanged(ref);
                    }
                    // openEphemeral, duplicate, requirePin: Known Gap, see
                    // Plan 6's Known gaps — none has a target workspace or
                    // PIN flow built anywhere yet.
                  },
                ),
              );
            },
            onOverflow: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsRoute())),
          ),
          if (_menuOpen) _menu(),
        ],
      ),
    );
  }

  Widget _menu() {
    final options = ref.watch(workspaceOptionsProvider);
    return SafeArea(
      child: Padding(
        // Sits directly under the 47px-tall workspace bar.
        padding: const EdgeInsets.only(top: 47),
        child: Align(
          alignment: Alignment.topCenter,
          child: options.maybeWhen(
            data: (options) => WorkspaceMenu(
              options: options,
              onPick: (id) {
                ref.read(activeWorkspaceIdProvider.notifier).state = id;
                setState(() => _menuOpen = false);
              },
              managementOptions: [
                ManagementOption(label: 'Today', onTap: () {
                  setState(() => _menuOpen = false);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TodayRoute()));
                }),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
    );
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
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ContainerRoute(site: site),
        ));
      },
      onBack: () => Navigator.pop(context),
    );
  }
}
