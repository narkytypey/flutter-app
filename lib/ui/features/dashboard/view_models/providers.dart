import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart';
import '../../../../data/repositories/site_repository_sqlite.dart';
import '../../../../data/repositories/workspace_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/models/workspace.dart';
import 'dashboard_view.dart';
import '../views/workspace_menu.dart';

/// Overridden in [main] with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden in main()'),
);

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

/// Seam for Plan 3: the filtering proxy will supply the real count. Until then
/// the dashboard honestly reports zero rather than inventing a number.
final leakCountProvider = Provider<int>((ref) => 0);

final dashboardProvider = FutureProvider<DashboardView>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  if (workspaces.isEmpty) {
    return const DashboardView(
      workspaceName: '',
      wipesOnExit: false,
      sessionCount: 0,
      leakCount: 0,
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
    leakCount: ref.watch(leakCountProvider),
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
