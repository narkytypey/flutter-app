import '../services/app_database.dart';
import 'site_repository_sqlite.dart';
import 'workspace_repository_sqlite.dart';

/// Copies the rows the user chose into the decoy's own store.
///
/// This runs once, when the decoy is set up or its selection is changed. After
/// it runs, the decoy store is an ordinary database of ordinary rows — there
/// is nothing in it to filter and nothing marked as hidden, which is why no
/// query in the decoy session has to remember to exclude anything.
///
/// Each copied site gets a fresh `profileId` (cross-plan issue #5): Plan 3
/// made that field required, and carrying the real site's profile across
/// would give the decoy copy the real copy's cookies and cache — one WebView
/// profile visible from both vaults, which is exactly what the two-vault
/// model exists to prevent.
Future<int> provisionDecoy({
  required AppDatabase from,
  required AppDatabase into,
}) async {
  final sourceWorkspaces = SqliteWorkspaceRepository(from);
  final sourceSites = SqliteSiteRepository(from);
  final targetWorkspaces = SqliteWorkspaceRepository(into);
  final targetSites = SqliteSiteRepository(into);

  var copied = 0;

  for (final workspace in await sourceWorkspaces.all()) {
    if (!workspace.showInDecoy) continue;

    await targetWorkspaces.upsert(workspace.copyWith(showInDecoy: false));

    for (final site in await sourceSites.inWorkspace(workspace.id)) {
      if (!site.showInDecoy) continue;
      await targetSites.upsert(
          site.copyWith(showInDecoy: false, profileId: newProfileId()));
      copied++;
    }
  }

  return copied;
}

/// Brings the decoy store back into agreement with which workspaces/sites
/// are currently flagged `showInDecoy` — adds newly flagged rows, removes
/// rows for anything un-flagged or deleted since the last sync, and leaves
/// alone anything the owner added directly while browsing inside the decoy
/// session.
///
/// The mechanism relies on an invariant [provisionDecoy] already
/// establishes: every synced row keeps the *same id* as its real-vault
/// source. Nothing else in the app ever writes a decoy-vault row using a
/// real-vault id, so any decoy row whose id matches one from `from` is
/// sync-owned by definition; a row whose id does not is decoy-original
/// content this function must never touch.
///
/// Unlike [provisionDecoy], an already-synced site keeps its existing
/// decoy-side `profileId` rather than getting a new one each call —
/// `profileId` is what Plan 3's WebView isolation keys cookies, cache, and
/// history to, and regenerating it on every call would silently wipe an
/// unchanged site's accumulated decoy browsing state each time. A fresh
/// `profileId` is only minted for a site with no existing decoy-side row.
///
/// Returns the number of sites newly added this call (not the total
/// flagged count).
Future<int> resyncDecoy({
  required AppDatabase from,
  required AppDatabase into,
}) async {
  final sourceWorkspaces = SqliteWorkspaceRepository(from);
  final sourceSites = SqliteSiteRepository(from);
  final targetWorkspaces = SqliteWorkspaceRepository(into);
  final targetSites = SqliteSiteRepository(into);

  final allWorkspaces = await sourceWorkspaces.all();
  final ownedWorkspaceIds = <String>{};
  final flaggedWorkspaceIds = <String>{};
  final ownedSiteIds = <String>{};
  final flaggedSiteIds = <String>{};

  var added = 0;

  for (final workspace in allWorkspaces) {
    ownedWorkspaceIds.add(workspace.id);
    final sites = await sourceSites.inWorkspace(workspace.id);
    for (final site in sites) {
      ownedSiteIds.add(site.id);
    }

    if (!workspace.showInDecoy) continue;
    flaggedWorkspaceIds.add(workspace.id);

    // Look up each site's existing decoy-side profileId *before* touching
    // the workspace row below: `targetWorkspaces.upsert` uses
    // ConflictAlgorithm.replace, which for an already-present workspace
    // deletes-then-reinserts it — and with foreign_keys ON and
    // sites.workspace_id REFERENCES workspaces(id) ON DELETE CASCADE, that
    // delete would wipe this workspace's decoy-side sites first, making
    // every site look brand new on every call.
    final existingProfileIds = <String, String>{};
    for (final site in sites) {
      final existing = await targetSites.byId(site.id);
      if (existing != null) existingProfileIds[site.id] = existing.profileId;
    }

    await targetWorkspaces.upsert(workspace.copyWith(showInDecoy: false));

    for (final site in sites) {
      if (!site.showInDecoy) continue;
      flaggedSiteIds.add(site.id);
      final existingProfileId = existingProfileIds[site.id];
      await targetSites.upsert(site.copyWith(
        showInDecoy: false,
        profileId: existingProfileId ?? newProfileId(),
      ));
      if (existingProfileId == null) added++;
    }
  }

  for (final decoyWorkspace in await targetWorkspaces.all()) {
    if (ownedWorkspaceIds.contains(decoyWorkspace.id) &&
        !flaggedWorkspaceIds.contains(decoyWorkspace.id)) {
      // Cascades that workspace's sites too — sites.workspace_id
      // REFERENCES workspaces(id) ON DELETE CASCADE, foreign_keys is ON.
      await targetWorkspaces.delete(decoyWorkspace.id);
    }
  }

  for (final decoyWorkspace in await targetWorkspaces.all()) {
    for (final decoySite in await targetSites.inWorkspace(decoyWorkspace.id)) {
      if (ownedSiteIds.contains(decoySite.id) &&
          !flaggedSiteIds.contains(decoySite.id)) {
        await targetSites.delete(decoySite.id);
      }
    }
  }

  return added;
}
