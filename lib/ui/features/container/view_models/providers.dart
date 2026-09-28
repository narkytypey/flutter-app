import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../data/services/container_engine_channel.dart';
import '../../../../data/services/container_panic_service.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/services/panic_service.dart';
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, vaultStoreProvider, biometricServiceProvider, SessionOpen;

final containerEngineProvider =
    Provider<ContainerEngine>((ref) => ChannelContainerEngine());

ContainerSession? _findSite(List<ContainerSession> sessions, String siteId) {
  for (final session in sessions) {
    if (session.siteId == siteId) return session;
  }
  return null;
}

/// The live session for one site, or `null` when that site has none. Feeds
/// [ContainerRoute]'s `opening -> live -> refused` state machine — see Task
/// 4. Filters [ContainerEngine.sessions] rather than adding a
/// per-site-keyed stream to the engine itself, since the engine already
/// emits its full list on every change and every existing caller
/// ([sessions]) wants that shape.
///
/// Combines a [ContainerEngine.liveSessions] snapshot with the
/// [ContainerEngine.sessions] stream, because that stream is broadcast with
/// no replay: [ContainerRoute] calls `open` from `initState`, ahead of the
/// first `build()` that creates this provider, so an engine that emits
/// before anyone listens needs the snapshot to be seen at all.
///
/// **Subscribe first, then read the snapshot.** The other order drops any
/// change emitted while the snapshot is in flight, and on a device that is
/// the common case, not an edge: `open` decides its route on a worker thread
/// and registers the session moments later, typically mid-snapshot. The lost
/// event left the route on the opening checklist forever. And once an event
/// has arrived, the snapshot is older than it and is discarded rather than
/// allowed to overwrite it.
final sessionForSiteProvider =
    StreamProvider.family<ContainerSession?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  final out = StreamController<ContainerSession?>();
  var sawEvent = false;
  final sub = engine.sessions().listen(
    (sessions) {
      sawEvent = true;
      out.add(_findSite(sessions, siteId));
    },
    onError: out.addError,
  );
  engine.liveSessions().then(
    (snapshot) {
      if (!sawEvent && !out.isClosed) out.add(_findSite(snapshot, siteId));
    },
    onError: (Object e, StackTrace s) {
      if (!out.isClosed) out.addError(e, s);
    },
  );
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
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
    destroyBiometricKey: () => ref.read(biometricServiceProvider).destroyKeyPair(),
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
