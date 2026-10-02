import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart';
import '../../../../data/repositories/site_repository_sqlite.dart';
import '../../../../data/repositories/workspace_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/models/workspace.dart';
import 'dashboard_view.dart';
import '../views/workspace_menu.dart';
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

/// Which sites are live. Runtime only — sessions never survive the app
/// closing, so this is deliberately not persisted.
final openSiteIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

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
        openCount: inWorkspace.where((s) => openIds.contains(s.id)).length,
      ),
      selected: workspace.id == activeId,
    ));
  }
  return options;
});

/// Marks [siteId] open and records the visit. Shared by `DashboardScreen`'s
/// own row tap and the search screen's result tap, so both always agree on
/// what "opening a site" means — today this in-memory badge, later Plan 6's
/// real `ContainerEngine` session, without either caller needing to change.
void openSite(WidgetRef ref, String siteId) {
  ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids, siteId});
  ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
  ref.invalidate(dashboardProvider);
}

/// The other half of [openSite]: called wherever a container closes a
/// session for good (the switcher's ×, "Close all and wipe", `6c`'s close
/// and wipe, `8c`'s close), so the dashboard stops listing it under OPEN NOW
/// and `9c` stops counting it. Backing out of a container does not call this
/// — its session stays open in the background.
void closeSite(WidgetRef ref, String siteId) {
  ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids}..remove(siteId));
  ref.invalidate(dashboardProvider);
}
