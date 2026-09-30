import '../../domain/models/site.dart';
import '../../domain/repositories/repositories.dart';
import 'app_database.dart';
import 'container_engine.dart';

/// Destroys a saved site's data and keeps the site: its session is closed,
/// its profile and kept downloads are wiped, and its row is given a fresh
/// `profileId`. Every path that wipes a saved site and keeps it goes through
/// here — the row menu's "Wipe this site's data" (`7b`), `6c`'s "Close and
/// wipe this session", `2c`'s "Close all and wipe" and `8c`'s "Close and
/// wipe" — so they cannot drift apart.
///
/// Closed first, since a profile in use cannot be deleted. The fresh id is
/// what makes the wipe whole: a profile this run has loaded can only have its
/// cookies, web storage and permissions cleared in place, and the rest waits
/// in the pending-deletion journal for the next start. Opening the site again
/// under the same id would take it off that journal (`ProfileManager
/// .profileFor`), leaving its cache, history and network state behind; under
/// a new id the old profile stays journaled and is deleted whole, and the
/// site starts clean now. The row is updated in place, so the site keeps its
/// id, settings and script assignments.
///
/// [site] should be the latest row, since it is written back as it is.
///
/// Only for saved sites. A throwaway has no row to rotate: its profile is
/// journaled from before it exists and is wiped with it, so its callers keep
/// calling the engine directly.
///
/// Not used for a wipe-on-exit site's automatic wipe, which runs natively
/// whenever its view closes — see Plan 6's Known gaps.
Future<Site> wipeSavedSite({
  required ContainerEngine engine,
  required SiteRepository sites,
  required Site site,
}) async {
  await engine.close(site.id);
  await engine.wipe(site.profileId);
  final fresh = site.copyWith(profileId: newProfileId());
  await sites.upsert(fresh);
  return fresh;
}

/// "Remove site" (`7b`): the same close and wipe as [wipeSavedSite], then the
/// row goes. Deleting the row alone left the site's WebView profile — its
/// logins and stored data — and its kept downloads on disk with nothing
/// pointing at them, and an open session running.
Future<void> removeSavedSite({
  required ContainerEngine engine,
  required SiteRepository sites,
  required Site site,
}) async {
  await engine.close(site.id);
  await engine.wipe(site.profileId);
  await sites.delete(site.id);
}
