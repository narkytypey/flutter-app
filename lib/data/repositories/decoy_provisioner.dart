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
