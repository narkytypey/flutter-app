import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart';
import '../../../../data/repositories/site_repository_sqlite.dart';
import '../../../../data/repositories/workspace_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/models/workspace.dart';
import 'dashboard_view.dart';
import '../views/workspace_menu.dart';
import '../../container/view_models/open_containers.dart' show openContainersProvider;
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, SessionOpen;

/// Overridden in [main] with the opened database.
/// Unlike Plan 1, nothing calls `databaseProvider.overrideWithValue` after
/// startup — there is no single startup-time database any more. Instead
/// this reads whichever vault `SessionController` currently has open, which
/// is how the dashboard ends up showing the right vault with no code
/// anywhere asking which one that is.
final databaseProvider = Provider<AppDatabase>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is! SessionOpen) {
    throw StateError('databaseProvider read while no vault is open');
  }
  return session.database;
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => SqliteWorkspaceRepository(ref.watch(databaseProvider)),
);

final siteRepositoryProvider = Provider<SiteRepository>(
  (ref) => SqliteSiteRepository(ref.watch(databaseProvider)),
);

final workspacesProvider = FutureProvider<List<Workspace>>(
  (ref) => ref.watch(workspaceRepositoryProvider).all(),
);

/// Null means "the first workspace"; set when the user picks one.
final activeWorkspaceIdProvider = StateProvider<String?>((ref) => null);

/// Every listed open container, throwaways included (tabs spec §5.4): read
/// from the registry, which is the only thing that decides what is open.
/// Runtime only — containers never survive the app closing or a lock.
///
/// Changes only when the set does, not on every registry change (each
/// page's navigation is one), so the dashboard does not re-query the vault
/// while a page loads behind it.
final openSiteIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(openContainersProvider.select((s) => _SiteIds(s.openSiteIds))).ids,
);

/// A set compared by its members, for `select`.
class _SiteIds {
  const _SiteIds(this.ids);
  final Set<String> ids;

  @override
  bool operator ==(Object other) => other is _SiteIds && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

/// Throwaways open under [workspaceId], their opener's workspace (tabs spec
/// §5.4).
int _throwawaysIn(Ref ref, String workspaceId) =>
    ref.watch(openContainersProvider.select((s) => s.throwawaysIn(workspaceId)));

final dashboardProvider = FutureProvider<DashboardView>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  if (workspaces.isEmpty) {
    return const DashboardView(
      workspaceName: '',
      wipesOnExit: false,
      sessionCount: 0,
      open: [],
      idle: [],
    );
  }

  final activeId = ref.watch(activeWorkspaceIdProvider);
  final workspace = workspaces.firstWhere(
    (w) => w.id == activeId,
    orElse: () => workspaces.first,
  );

  final sites = await ref.watch(siteRepositoryProvider).inWorkspace(workspace.id);

  return DashboardView.from(
    workspace: workspace,
    sites: sites,
    openSiteIds: ref.watch(openSiteIdsProvider),
    throwawaysOpen: _throwawaysIn(ref, workspace.id),
    now: DateTime.now(),
  );
});

/// The switcher's rows, with each workspace's site and open counts.
final workspaceOptionsProvider = FutureProvider<List<WorkspaceOption>>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  final sites = ref.watch(siteRepositoryProvider);
  final openIds = ref.watch(openSiteIdsProvider);
  final activeId = ref.watch(activeWorkspaceIdProvider) ??
      (workspaces.isEmpty ? null : workspaces.first.id);

  final options = <WorkspaceOption>[];
  for (final workspace in workspaces) {
    final inWorkspace = await sites.inWorkspace(workspace.id);
    options.add(WorkspaceOption(
      id: workspace.id,
      name: workspace.name,
      meta: workspaceMeta(
        workspace: workspace,
        siteCount: inWorkspace.length,
        openCount: inWorkspace.where((s) => openIds.contains(s.id)).length +
            _throwawaysIn(ref, workspace.id),
      ),
      selected: workspace.id == activeId,
    ));
  }
  return options;
});

/// Records a visit to [siteId]. Shared by `DashboardScreen`'s own row tap,
/// the search screen's result tap and the address bar's saved-site
/// destination, so all three agree on what "opening a site" records. The
/// registry, not this, decides what is open (tabs spec §5.4): `showContainer`
/// tells it.
void openSite(WidgetRef ref, String siteId) {
  ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
  ref.invalidate(dashboardProvider);
}
