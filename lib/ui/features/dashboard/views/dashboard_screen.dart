import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart'
    show allSitesProvider, searchQueryProvider, searchResultsProvider;
import '../../search/view_models/search_view.dart' show SearchResultEntry;
import '../../search/views/search_screen.dart';
import '../../settings/view_models/providers.dart'
    show
        biometricsAvailableProvider,
        biometricsEnabledProvider,
        settingsControllerProvider;
import '../../settings/views/settings_screen.dart';
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'site_row_menu.dart';
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
                    ref.invalidate(dashboardProvider);
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
                            ref.invalidate(dashboardProvider);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      ));
                    } else if (action == SiteRowAction.removeSite) {
                      await ref.read(siteRepositoryProvider).delete(siteId);
                      ref.invalidate(dashboardProvider);
                    }
                    // openEphemeral, duplicate, requirePin, wipeData: Known Gap,
                    // see this plan's Known Gaps section — none has a target
                    // workspace/wipe-confirmation flow built anywhere yet.
                  },
                ),
              );
            },
            onOverflow: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const _SettingsRoute())),
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

class _SettingsRoute extends ConsumerWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometrics = ref.watch(biometricsEnabledProvider);
    final biometricsAvailable = ref.watch(biometricsAvailableProvider);
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      biometricsAvailable: biometricsAvailable.value ?? false,
      autoLockLabel: 'After 1 min',
      decoyEnabled: false,
      decoySiteCount: 0,
      hideFromSwitcher: true,
      panicOnFlip: false,
      onPanicLabel: 'Wipe + lock',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        }
      },
      onTap: (_) {},
    );
  }
}
