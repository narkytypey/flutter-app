import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../data/services/container_engine_channel.dart';
import '../../../../data/services/container_panic_service.dart';
import '../../../../domain/services/panic_service.dart';
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, vaultStoreProvider, SessionOpen;

final containerEngineProvider =
    Provider<ContainerEngine>((ref) => ChannelContainerEngine());

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
    destroyVaults: () => ref.read(vaultStoreProvider).destroy(),
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
/// Not yet called from any widget — nothing in the tree constructs
/// `ContainerScreen` outside its own widget test yet (a separate,
/// not-yet-written integration plan wires real navigation). Kept here,
/// ready to pass as `ContainerScreen(onPanic: () => _panic(ref), ...)` once
/// that call site exists.
// ignore: unused_element
Future<void> _panic(WidgetRef ref) async {
  final report = await ref.read(panicServiceProvider).trigger();
  ref.read(sessionProvider.notifier).panicked(report);
}
