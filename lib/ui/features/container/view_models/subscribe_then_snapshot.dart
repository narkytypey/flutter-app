import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [events], preceded by [snapshot]'s value when no event has arrived first.
///
/// For an engine stream that is broadcast with no replay. `ContainerRoute`
/// calls `open` from `initState`, ahead of the first `build()` that creates a
/// provider using this, so an engine that emits before anyone listens needs
/// the snapshot to be seen at all.
///
/// **Subscribe first, then read the snapshot.** The other order drops any
/// change emitted while the snapshot is in flight, and on a device that is
/// the common case, not an edge: `open` decides its route on a worker thread
/// and registers the session moments later, typically mid-snapshot. The lost
/// event left the route on the opening checklist forever (`7996a17`). And
/// once an event has arrived, the snapshot is older than it and is discarded
/// rather than allowed to overwrite it.
///
/// Shared by `sessionForSiteProvider` and `navigationForSiteProvider` rather
/// than written twice: the race is subtle enough to get wrong again.
Stream<T> subscribeThenSnapshot<T>(
  Ref ref, {
  required Stream<T> events,
  required Future<T> Function() snapshot,
}) {
  final out = StreamController<T>();
  var sawEvent = false;
  final sub = events.listen(
    (value) {
      sawEvent = true;
      out.add(value);
    },
    onError: out.addError,
  );
  snapshot().then(
    (value) {
      if (!sawEvent && !out.isClosed) out.add(value);
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
}
