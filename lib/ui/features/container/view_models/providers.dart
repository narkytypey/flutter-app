import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show deleteVaultStore;
import '../../../../data/services/bundled_filter_lists.dart';
import '../../../../data/services/container_engine.dart';
import '../../../../data/services/container_engine_channel.dart';
import '../../../../data/services/container_panic_service.dart';
import '../../../../data/services/engine_extras_builder.dart';
import '../../../../domain/models/engine_extras.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/services/panic_service.dart';
import '../../scripts/view_models/providers.dart'
    show filterListRepositoryProvider, scriptRepositoryProvider;
import '../../settings/view_models/providers.dart' show settingsRepositoryProvider;
import '../../shell/view_models/session_controller.dart'
    show
        sessionProvider,
        vaultStoreProvider,
        biometricServiceProvider,
        documentsDirectoryProvider,
        vaultDatabasePath,
        SessionOpen;

final containerEngineProvider =
    Provider<ContainerEngine>((ref) => ChannelContainerEngine());

final bundledFilterRulesProvider =
    Provider<BundledFilterRules>((ref) => defaultBundledFilterRules);

/// What a site opens with from the open vault — its enabled filter lists'
/// rules, its library scripts and its effective security level. A function
/// rather than a value so every open reads the vault as it is now, the vault
/// default level included; widget tests with no vault override it.
final engineExtrasBuilderProvider = Provider<Future<EngineExtras> Function(Site)>((ref) {
  return (site) => engineExtrasFor(
        site,
        filterLists: ref.read(filterListRepositoryProvider),
        scripts: ref.read(scriptRepositoryProvider),
        rules: ref.read(bundledFilterRulesProvider),
        settings: ref.read(settingsRepositoryProvider),
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
