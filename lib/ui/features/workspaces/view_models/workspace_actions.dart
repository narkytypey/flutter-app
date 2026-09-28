import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../data/services/container_engine.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/services/workspace_storage_service.dart';
import '../../../../domain/workspace_stats.dart';
import '../views/workspace_form_screen.dart';
import '../views/workspaces_screen.dart';

/// What the Workspaces screens (`10a`–`10c`) do to the open vault.
class WorkspaceActions {
  WorkspaceActions({
    required this.workspaces,
    required this.sites,
    required this.engine,
    required this.storage,
  });

  final WorkspaceRepository workspaces;
  final SiteRepository sites;
  final ContainerEngine engine;
  final WorkspaceStorageService storage;

  Future<List<WorkspaceListItem>> listItems() async {
    return [
      for (final workspace in await workspaces.all())
        WorkspaceListItem(
          id: workspace.id,
          name: workspace.name,
          markerIndex: workspace.markerIndex,
          statsLine: workspaceStatsLine(
            storageRule: workspace.storageRule,
            siteCount: (await sites.inWorkspace(workspace.id)).length,
            storageBytes: await storage.bytesFor(workspace.id),
          ),
        ),
    ];
  }

  Future<void> create(WorkspaceFormResult result) async {
    final existing = await workspaces.all();
    final sortIndex = existing.isEmpty
        ? 0
        : existing.map((w) => w.sortIndex).reduce((a, b) => a > b ? a : b) + 1;
    await workspaces.upsert(Workspace(
      id: newProfileId(),
      name: result.name,
      markerIndex: result.markerIndex,
      storageRule: result.storageRule,
      requirePin: result.requirePin,
      showInDecoy: result.showInDecoy,
      sortIndex: sortIndex,
    ));
  }

  Future<void> update(Workspace workspace, WorkspaceFormResult result) {
    return workspaces.upsert(workspace.copyWith(
      name: result.name,
      markerIndex: result.markerIndex,
      storageRule: result.storageRule,
      requirePin: result.requirePin,
      showInDecoy: result.showInDecoy,
    ));
  }

  /// Every site's container is closed and its profile wiped before the rows
  /// go: the database cascade removes the sites, but their WebView profiles
  /// — logins and stored data, which `10c` promises are destroyed — live on
  /// disk outside it. Closed first, since a profile in use cannot be deleted.
  Future<void> delete(Workspace workspace) async {
    for (final site in await sites.inWorkspace(workspace.id)) {
      await engine.close(site.id);
      await engine.wipe(site.profileId);
    }
    await workspaces.delete(workspace.id);
  }
}
