import 'destination.dart';
import 'monogram_suggestion.dart';
import 'site.dart';

/// The in-memory [Site] a throwaway container runs as (spec §5.1). Nothing
/// writes it to the vault until the user saves it.
///
/// Only the route is inherited, carried by [destination] from the container
/// it was typed in. Every other field is `Site()`'s default — trackers,
/// WebRTC and fingerprinting blocked, no hardware or clipboard access, no
/// custom CSS or JS, the Android user agent, force-dark on — so a throwaway
/// never inherits another site's grants. Its id is fresh, so no library
/// script applied to another site selects it either. [current] supplies only
/// the workspace the save form defaults to. [newId] makes the id and the
/// profile id (`newProfileId` in the app).
Site buildThrowaway({
  required Throwaway destination,
  required Site current,
  required String Function() newId,
}) {
  final host = destination.url.host;
  return Site(
    id: newId(),
    profileId: newId(),
    workspaceId: current.workspaceId,
    name: host,
    monogram: suggestMonogram(host),
    url: destination.url.toString(),
    cookiePolicy: CookiePolicy.wipeOnExit,
    proxyMode: destination.mode,
    proxyHost: destination.proxyHost,
    proxyPort: destination.proxyPort,
  );
}
