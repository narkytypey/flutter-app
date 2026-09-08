import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../data/services/container_engine_channel.dart';
import '../../../../data/services/container_panic_service.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/services/panic_service.dart';
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, vaultStoreProvider, SessionOpen;

final containerEngineProvider =
    Provider<ContainerEngine>((ref) => ChannelContainerEngine());

/// The live session for one site, or `null` when that site has none. Feeds
/// [ContainerRoute]'s `opening -> live -> refused` state machine — see Task
/// 4. Filters [ContainerEngine.sessions] rather than adding a
/// per-site-keyed stream to the engine itself, since the engine already
/// emits its full list on every change and every existing caller
/// ([sessions]) wants that shape.
///
/// Yields a [liveSessions] snapshot before subscribing to [sessions]'
/// broadcast stream, rather than watching the stream alone. `sessions()` is
/// a broadcast stream with no replay, and [ContainerRoute] calls
/// `ContainerEngine.open` from `initState` — synchronously ahead of the
/// first `build()` that creates this provider and subscribes to it, so a
/// fake (or a fast real) engine that resolves and emits before that
/// subscription exists would otherwise leave this provider stuck in
/// `AsyncLoading` forever. The snapshot closes that gap the same way
/// [ContainerEngine.liveSessions]'s own doc comment describes it fixing for
/// panic's session count.
ContainerSession? _findSite(List<ContainerSession> sessions, String siteId) {
  for (final session in sessions) {
    if (session.siteId == siteId) return session;
  }
  return null;
}

final sessionForSiteProvider =
    StreamProvider.family<ContainerSession?, String>((ref, siteId) async* {
  final engine = ref.watch(containerEngineProvider);
  yield _findSite(await engine.liveSessions(), siteId);
  yield* engine.sessions().map((sessions) => _findSite(sessions, siteId));
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
/// Called from [ContainerRoute]'s `onPanic` (Task 4) — the real call site
/// this was written ahead of.
Future<void> panic(WidgetRef ref) async {
  final report = await ref.read(panicServiceProvider).trigger();
  ref.read(sessionProvider.notifier).panicked(report);
}
