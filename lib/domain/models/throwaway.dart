import 'destination.dart';
import 'monogram_suggestion.dart';
import 'site.dart';

/// The in-memory [Site] a throwaway container runs as (spec §5.1). Nothing
/// writes it to the vault until the user saves it.
///
/// Only the route, its proxy login included, is inherited, carried by
/// [destination]. Every other field is `Site()`'s default (trackers,
/// WebRTC and fingerprinting blocked, no hardware or clipboard access, no
/// custom CSS or JS, the Android user agent, force-dark on), so a throwaway
/// never inherits another site's grants. Its id is fresh, so no library
/// script applied to another site selects it either. [workspaceId] is the
/// workspace it counts under and its save form defaults to: its opener's, or
/// the dashboard's viewed chip (dashboard spec §5). [newId] makes the id and
/// the profile id (`newProfileId` in the app). With per-site login on, the
/// fresh profile id gives the throwaway its own login.
Site buildThrowaway({
  required Throwaway destination,
  required String workspaceId,
  required String Function() newId,
}) {
  final host = destination.url.host;
  return Site(
    id: newId(),
    profileId: newId(),
    workspaceId: workspaceId,
    name: host,
    monogram: suggestMonogram(host),
    url: destination.url.toString(),
    cookiePolicy: CookiePolicy.wipeOnExit,
    proxyMode: destination.mode,
    proxyHost: destination.proxyHost,
    proxyPort: destination.proxyPort,
    proxyUser: destination.proxyUser,
    proxyPassword: destination.proxyPassword,
    proxyLoginPerSite: destination.proxyLoginPerSite,
  );
}
