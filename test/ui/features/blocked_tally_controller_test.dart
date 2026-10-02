import 'dart:async';

import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart';
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

/// A session this test moves by hand: open, then closed.
class _Session extends SessionController {
  _Session(this.initial);
  final Session initial;

  @override
  Session build() => initial;

  void become(Session next) => state = next;
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

  // A reopened site's new session counts from zero again. Remembering the
  // closed session's counts would swallow the new one's first blocks.
  test('a site closed and reopened counts its new session from zero', () async {
    final engine = FakeContainerEngine();
    final site = _site('s1');
    final container = _container(engine, (id) async => site);

    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.trackers, 5);
    await _settle();
    await engine.close('s1');
    await _settle();
    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.trackers, 3);
    await _settle();

    expect(_count(container.read(blockedTallyProvider), BlockedCategory.trackers), 8);
  });

  // A lookup still in flight when the vault changes must not land in the new
  // vault's tally: that is a count from one vault shown in the other.
  test("a vault switch mid-lookup drops the old vault's count", () async {
    final engine = FakeContainerEngine();
    final site = _site('s1');
    final vault = StateProvider<String>((ref) => 'a');
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
      siteLookupProvider.overrideWith((ref) {
        final open = ref.watch(vault);
        return (id) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return open == 'a' ? site : null;
        };
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(blockedTallyProvider, (_, __) {});

    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.trackers, 5);
    await Future<void>.delayed(Duration.zero);
    container.read(vault.notifier).state = 'b';
    container.read(blockedTallyProvider);
    await _settle();

    expect(container.read(blockedTallyProvider).total, 0);
  });

  // A container keeps the tally listened, so it is rebuilt as the vault
  // closes. Its site lookup read `databaseProvider`, which throws once no
  // vault is open: an unhandled exception on every lock and every panic.
  group('the tally survives the vault closing', () {
    for (final (name, closed) in [
      ('a lock', const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate())),
      ('a panic', const SessionPanicked(PanicReport(sessionsDestroyed: 1))),
    ]) {
      test(name, () async {
        sqfliteFfiInit();
        final database =
            await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
        addTearDown(database.close);
        final container = ProviderContainer(overrides: [
          containerEngineProvider.overrideWithValue(FakeContainerEngine()),
          sessionProvider.overrideWith(() => _Session(SessionOpen(
                vault: VaultId.a, database: database, dataKey: Uint8List(32)))),
        ]);
        addTearDown(container.dispose);
        container.listen(blockedTallyProvider, (_, __) {});
        expect(container.read(blockedTallyProvider).total, 0);

        final errors = <Object>[];
        await runZonedGuarded(() async {
          (container.read(sessionProvider.notifier) as _Session).become(closed);
          await _settle();
        }, (error, _) => errors.add(error));

        expect(errors, isEmpty);
        expect(container.read(blockedTallyProvider).total, 0);
      });
    }
  });
}
