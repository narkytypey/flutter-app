import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart';
import '../../../../data/repositories/site_repository_sqlite.dart';
import '../../../../data/repositories/workspace_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/models/workspace.dart';
import 'dashboard_view.dart';
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

/// The viewed chip (dashboard spec §4.2). Null means the first workspace.
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

final dashboardProvider = FutureProvider<DashboardView>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  if (workspaces.isEmpty) return DashboardView.empty;

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
    now: DateTime.now(),
  );
});

/// Records a visit to [siteId]. Shared by a dashboard row's tap and the
/// saved-site destinations of the address bar and the dashboard's search
/// field, so all three agree on what "opening a site" records. The registry,
/// not this, decides what is open (tabs spec §5.4): `showContainer` tells it.
void openSite(WidgetRef ref, String siteId) {
  ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
  ref.invalidate(dashboardProvider);
}
