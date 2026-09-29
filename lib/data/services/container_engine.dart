import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/navigation_state.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/site.dart';

/// Everything Dart is allowed to know about the platform. No WebView type
/// crosses this line.
abstract interface class ContainerEngine {
  /// False when the device cannot isolate. The app refuses to open containers
  /// rather than sharing a profile — see Global Constraints.
  Future<bool> isolationAvailable();

  /// Creates the profile if absent and begins loading. Emits progress on
  /// [sessions]. Completes when the page is live or the route was refused.
  /// [extras] is the open vault's filter rules and scripts for this site.
  /// [throwaway] marks an in-memory site (browser-chrome spec §5.4): the
  /// platform journals its profile before creating it, so a crash cannot
  /// leak it, and always wipes it on exit.
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
  });

  /// Destroys the profile's cookies, cache and storage. Called for
  /// `CookiePolicy.wipeOnExit` and by "Close all and wipe" in `2c`.
  Future<void> wipe(String profileId);

  /// Destroys every profile the platform holds, including ones this process
  /// cannot name.
  ///
  /// Panic calls this, and it exists because [wipe] cannot do that job. A
  /// profile id lives in a `Site` row inside an encrypted vault, so the ids
  /// belonging to the vault that is *not* open are unreadable to this
  /// process — before panic starts, not merely after it finishes. A loop over
  /// [wipe] would clear the open vault's containers and silently leave the
  /// other vault's storage sitting on disk. Asking the platform which
  /// profiles exist is the only enumeration that can see both. See Task 9.
  Future<void> wipeAll();

  Future<void> close(String siteId);

  /// Every live session. Spec `2c`'s drawer renders exactly this.
  Stream<List<ContainerSession>> sessions();

  /// The same list [sessions] emits, read once.
  ///
  /// [sessions] is a broadcast stream that fires only on change, so awaiting
  /// its `.first` on a cold app blocks forever instead of yielding an empty
  /// list. Anything needing a snapshot rather than a subscription — panic
  /// counting what it is about to destroy, for one — uses this.
  Future<List<ContainerSession>> liveSessions();

  Future<void> reload(String siteId);

  /// Hardware asks the platform is holding, waiting on the user's decision.
  /// Filtered to the foreground site by whoever listens — see Task 4.
  Stream<PendingPermissionRequest> permissionRequests();

  /// Tells the platform what the user picked for [requestId]. A decision for
  /// a request that already timed out or whose site closed is a silent
  /// no-op on the platform side, not an error here.
  Future<void> resolvePermission(String requestId, PermissionDecision decision);

  Stream<HeldDownloadEvent> downloads();
  Future<void> resolveDownload(String requestId, DownloadDecision decision);
  Stream<DownloadResult> downloadResults();

  /// A *live* session's tunnel failing mid-browse. Distinct from
  /// [SessionPhase.refused], which only ever happens before a session goes
  /// live — see Plan 6's design spec §3.
  Stream<TunnelDroppedEvent> tunnelDropped();

  /// Runs the reader-mode heuristic against the page currently loaded for
  /// [siteId]. Returns `null` when extraction finds nothing article-shaped.
  Future<ReaderArticle?> extractArticle(String siteId);

  /// Every page change in every open container (browser-chrome spec §3.1).
  /// Broadcast with no replay: a change made before anyone listened is only
  /// in [navigationState].
  Stream<NavigationState> navigation();

  /// The last [navigation] event for [siteId], or null before its first.
  Future<NavigationState?> navigationState(String siteId);

  /// The finished count of each find in page (spec §6.5).
  Stream<FindResult> findResults();

  // The in-page controls below are each a silent no-op on a closed or
  // unknown session, like [reload].

  Future<void> goBack(String siteId);
  Future<void> goForward(String siteId);
  Future<void> stop(String siteId);

  /// Loads [url] in [siteId]'s own container, on its own route. The platform
  /// refuses every scheme but `http` and `https`.
  Future<void> loadUrl(String siteId, String url);

  /// Highlights [query] in the page. An empty query is [clearFind]'s job.
  Future<void> find(String siteId, String query);
  Future<void> findNext(String siteId, {required bool forward});
  Future<void> clearFind(String siteId);

  /// A throwaway saved as a site (spec §5.3–5.4): its profile stops being
  /// wiped on exit and leaves the crash journal, so the login just saved
  /// survives closing the page.
  Future<void> keep(String siteId);
}
