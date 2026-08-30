import '../../domain/models/container_session.dart';
import '../../domain/models/site.dart';

/// Everything Dart is allowed to know about the platform. No WebView type
/// crosses this line.
abstract interface class ContainerEngine {
  /// False when the device cannot isolate. The app refuses to open containers
  /// rather than sharing a profile — see Global Constraints.
  Future<bool> isolationAvailable();

  /// Creates the profile if absent and begins loading. Emits progress on
  /// [sessions]. Completes when the page is live or the route was refused.
  Future<ContainerSession> open(Site site);

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
}
