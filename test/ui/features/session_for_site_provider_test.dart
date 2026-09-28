import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/container_session.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site() => Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
      proxyMode: ProxyMode.direct,
    );

/// Registers the site *while* its snapshot is being read, and hands back the
/// snapshot as it stood before — what a device does when `open`'s route probe
/// finishes on a worker thread during the provider's `liveSessions` call.
class _OpenLandsDuringSnapshot extends FakeContainerEngine {
  _OpenLandsDuringSnapshot() : super(opensLive: false);

  @override
  Future<List<ContainerSession>> liveSessions() async {
    final stale = await super.liveSessions();
    await open(_site());
    return stale;
  }
}

void main() {
  // On a device the session registered in that window was never seen: the
  // broadcast stream dropped its only event because the provider subscribed
  // after the snapshot, so the route waited on the checklist forever.
  test('a session registered during the snapshot read is not lost', () async {
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(_OpenLandsDuringSnapshot()),
    ]);
    addTearDown(container.dispose);

    final seen = <ContainerSession?>[];
    container.listen(
      sessionForSiteProvider('s1'),
      (_, next) => next.whenData(seen.add),
      fireImmediately: true,
    );
    await pumpEventQueue();

    expect(seen.last?.phase, SessionPhase.opening);
  });

  test('a later change still arrives after the snapshot', () async {
    final engine = FakeContainerEngine(opensLive: false);
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);

    final seen = <ContainerSession?>[];
    container.listen(
      sessionForSiteProvider('s1'),
      (_, next) => next.whenData(seen.add),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(seen.last, isNull);

    await engine.open(_site());
    engine.markLive('s1');
    await pumpEventQueue();

    expect(seen.last?.phase, SessionPhase.live);
  });
}
