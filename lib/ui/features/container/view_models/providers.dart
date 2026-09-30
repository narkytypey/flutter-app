import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show deleteVaultStore;
import '../../../../data/services/bundled_filter_lists.dart';
import '../../../../data/services/container_engine.dart';
import '../../../../data/services/container_engine_channel.dart';
import '../../../../data/services/container_panic_service.dart';
import '../../../../data/services/engine_extras_builder.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_extras.dart';
import '../../../../domain/models/navigation_state.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/services/panic_service.dart';
import '../../scripts/view_models/providers.dart'
    show filterListRepositoryProvider, scriptRepositoryProvider;
import '../../shell/view_models/session_controller.dart'
    show
        sessionProvider,
        vaultStoreProvider,
        biometricServiceProvider,
        documentsDirectoryProvider,
        vaultDatabasePath,
        SessionOpen;
import 'subscribe_then_snapshot.dart';

final containerEngineProvider =
    Provider<ContainerEngine>((ref) => ChannelContainerEngine());

final bundledFilterRulesProvider =
    Provider<BundledFilterRules>((ref) => defaultBundledFilterRules);

/// What a site opens with from the open vault — its enabled filter lists'
/// rules and its library scripts. A function rather than a value so every
/// open reads the vault as it is now; widget tests with no vault override it.
final engineExtrasBuilderProvider = Provider<Future<EngineExtras> Function(Site)>((ref) {
  return (site) => engineExtrasFor(
        site,
        filterLists: ref.read(filterListRepositoryProvider),
        scripts: ref.read(scriptRepositoryProvider),
        rules: ref.read(bundledFilterRulesProvider),
      );
});

ContainerSession? _findSite(List<ContainerSession> sessions, String siteId) {
  for (final session in sessions) {
    if (session.siteId == siteId) return session;
  }
  return null;
}

/// The live session for one site, or `null` when that site has none. Feeds
/// [ContainerRoute]'s `opening -> live -> refused` state machine. Filters
/// [ContainerEngine.sessions] rather than adding a per-site-keyed stream to
/// the engine itself, since the engine already emits its full list on every
/// change and every existing caller ([sessions]) wants that shape. Any
/// sessions event supersedes the snapshot — see [subscribeThenSnapshot].
///
/// Auto-disposed with the route that watches it, like
/// [navigationForSiteProvider]: a throwaway's id is never seen again once its
/// route is gone, and a family kept for the life of the app would hold one
/// engine subscription per throwaway ever opened.
final sessionForSiteProvider =
    StreamProvider.autoDispose.family<ContainerSession?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  return subscribeThenSnapshot<ContainerSession?>(
    ref,
    events: engine.sessions().map((sessions) => _findSite(sessions, siteId)),
    snapshot: () => engine.liveSessions().then((sessions) => _findSite(sessions, siteId)),
  );
});

/// The page one site's container is showing (browser-chrome spec §3.2): its
/// address, history and load progress, or `null` before its view has
/// reported anything. Has `sessionForSiteProvider`'s race exactly — the first
/// load can report before anyone listens — hence the shared helper.
///
/// Auto-disposed with its route, so a site opened again starts from its new
/// page rather than showing the last visit's address and history until the
/// first report.
final navigationForSiteProvider =
    StreamProvider.autoDispose.family<NavigationState?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  return subscribeThenSnapshot<NavigationState?>(
    ref,
    events: engine.navigation().where((state) => state.siteId == siteId),
    snapshot: () => engine.navigationState(siteId),
  );
});

/// Fills the seam Plan 2 Task 7 left open.
///
/// `closeDatabase` is a no-op when no vault is open, which is a reachable
/// state rather than a defensive nicety: panic lives on `2b`'s top bar and
/// `2c`'s footer, and it has to survive being triggered with nothing open
/// instead of throwing on a null database.
final panicServiceProvider = Provider<PanicService>((ref) {
  return ContainerPanicService(
    engine: ref.read(containerEngineProvider),
    closeDatabase: () async {
      final session = ref.read(sessionProvider);
      if (session is SessionOpen) await session.database.close();
    },
    // PanicService's step 3, "delete the store files", after the keys: a
    // store left behind outlives its key and blocks the next setup.
    destroyVaults: () async {
      await ref.read(vaultStoreProvider).destroy();
      final documents = ref.read(documentsDirectoryProvider);
      for (final vault in VaultId.values) {
        await deleteVaultStore(vaultDatabasePath(documents, vault));
      }
    },
    // Both vaults' keys, not just the open one's: panic runs from either.
    destroyBiometricKeys: () =>
        ref.read(biometricServiceProvider).destroyAllKeyPairs(),
  );
});

/// The handler both of `2b`'s top-bar `◉` and `2c`'s switcher-sheet panic
/// button call. `AppGate` already watches [sessionProvider], so moving to
/// `SessionPanicked` replaces the whole tree with `3c` — no route is pushed,
/// because a pushed route would leave this screen and its WebViews mounted
/// underneath, which is both a live surface and a lie about what just
/// happened. No confirmation dialog: `3c` reports afterwards, it does not
/// ask first.
///
/// Called from [ContainerRoute]'s `onPanic` (Task 4) — the real call site
/// this was written ahead of.
Future<void> panic(WidgetRef ref) async {
  final report = await ref.read(panicServiceProvider).trigger();
  ref.read(sessionProvider.notifier).panicked(report);
}
