import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emits a page change *while* the snapshot is being read, and hands back
/// the snapshot as it stood before — the same race `sessionForSiteProvider`
/// lost on a device, now for navigation.
class _EventLandsDuringSnapshot extends FakeContainerEngine {
  @override
  Future<NavigationState?> navigationState(String siteId) async {
    final stale = await super.navigationState(siteId);
    emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/new', loading: true));
    return stale;
  }
}

List<NavigationState?> _watch(ProviderContainer container) {
  final seen = <NavigationState?>[];
  container.listen(
    navigationForSiteProvider('s1'),
    (_, next) => next.whenData(seen.add),
    fireImmediately: true,
  );
  return seen;
}

void main() {
  test('a page change during the snapshot read is not lost', () async {
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(_EventLandsDuringSnapshot()),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();

    expect(seen.last?.url, 'https://forum.example.com/new');
  });

  test('the snapshot stands in until the first event, which replaces it', () async {
    final engine = FakeContainerEngine()
      ..seedNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/a'));
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();
    expect(seen.last?.url, 'https://forum.example.com/a');

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/b'));
    await pumpEventQueue();
    expect(seen.last?.url, 'https://forum.example.com/b');
  });

  test("another site's page changes are not this site's", () async {
    final engine = FakeContainerEngine();
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();
    engine.emitNavigation(const NavigationState(siteId: 's2', url: 'https://elsewhere.example.com'));
    await pumpEventQueue();

    expect(seen, [null]);
  });
}
