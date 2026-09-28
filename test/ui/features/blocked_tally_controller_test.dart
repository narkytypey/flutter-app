import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(String id) => Site(
      id: id, workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
    );

ProviderContainer _container(
  FakeContainerEngine engine,
  Future<Site?> Function(String) lookup,
) {
  final container = ProviderContainer(overrides: [
    containerEngineProvider.overrideWithValue(engine),
    siteLookupProvider.overrideWithValue(lookup),
  ]);
  addTearDown(container.dispose);
  container.listen(blockedTallyProvider, (_, __) {});
  return container;
}

int _count(BlockedTally tally, BlockedCategory category) =>
    tally.categories.where((c) => c.category == category).fold(0, (a, c) => a + c.count);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('a session emission increments the tally by the delta, not the running total', () async {
    final engine = FakeContainerEngine();
    final site = _site('s1');
    final container = _container(engine, (id) async => id == 's1' ? site : null);

    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.trackers, 5);
    await _settle();
    engine.addBlocked('s1', BlockedCategory.trackers, 3);
    await _settle();

    final tally = container.read(blockedTallyProvider);
    expect(_count(tally, BlockedCategory.trackers), 8);
    expect(tally.sites.single.count, 8);
  });

  test('leakCountProvider mirrors the tally total', () async {
    final engine = FakeContainerEngine();
    final site = _site('s1');
    final container = _container(engine, (id) async => id == 's1' ? site : null);

    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.ads, 2);
    await _settle();

    expect(container.read(leakCountProvider), 2);
  });

  // A session whose site is not in the open vault belongs to the other one.
  // Counting it would be an aggregate across both vaults.
  test("a session whose site is not in this vault is not counted at all", () async {
    final engine = FakeContainerEngine();
    final container = _container(engine, (id) async => null);

    await engine.open(_site('other-vault'));
    engine.addBlocked('other-vault', BlockedCategory.trackers, 4);
    await _settle();

    expect(container.read(blockedTallyProvider).total, 0);
  });

  // The lookup is async. Handled concurrently, an older emission resumes
  // after a newer one and writes its stale counts back as the last ones seen,
  // so the next emission counts the same blocks a second time.
  test('an emission is not undone by an older one still looking its site up', () async {
    final engine = FakeContainerEngine();
    final sites = {'s1': _site('s1'), 's2': _site('s2')};
    final container = _container(engine, (id) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return sites[id];
    });

    await engine.open(sites['s1']!);
    await engine.open(sites['s2']!);
    await _settle();
    engine.addBlocked('s1', BlockedCategory.ads, 1);
    engine.addBlocked('s2', BlockedCategory.trackers, 5);
    await _settle();
    engine.addBlocked('s1', BlockedCategory.ads, 1);
    await _settle();

    final tally = container.read(blockedTallyProvider);
    expect(_count(tally, BlockedCategory.trackers), 5);
    expect(_count(tally, BlockedCategory.ads), 2);
  });
}
