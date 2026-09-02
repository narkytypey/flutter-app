import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show openSiteIdsProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  // `SessionController.build` starts a `LifecycleController`, which reaches
  // for `WidgetsBinding.instance`. These are plain `test()`s, so nothing has
  // created a binding for it.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  late FakeCrypto crypto;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('session-test');
    crypto = FakeCrypto();
    vaultStore = VaultStore(crypto, File('${dir.path}/meta.bin'));
  });

  tearDown(() => dir.delete(recursive: true));

  ProviderContainer buildContainer(Session initial) {
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(initial),
      vaultOpenerProvider.overrideWithValue(
        ({required String path, required Uint8List dataKey}) => AppDatabase.open(
            path: inMemoryDatabasePath, factory: databaseFactoryFfi),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh device starts unconfigured', () {
    final container = buildContainer(const SessionUnconfigured());
    expect(container.read(sessionProvider), isA<SessionUnconfigured>());
  });

  test('a correct main PIN opens vault A', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
  });

  test('a wrong PIN counts down and stays locked', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('999999');

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.wrong);
    expect(session.gate.triesLeft, 4);
  });

  test(
      'returning within the grace period locks to welcomeBack, not silently '
      'to the board', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container =
        buildContainer(SessionOpen(vault: VaultId.a, database: db));
    container.read(openSiteIdsProvider.notifier).state = {'s1', 's2'};

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.board);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.welcomeBack);
    expect(session.openSessionCount, 2);
    expect(session.lockDeadline, isNotNull);
  });

  test('returning past the grace period locks to afterTimeout and wipes sessions',
      () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container =
        buildContainer(SessionOpen(vault: VaultId.a, database: db));
    container.read(openSiteIdsProvider.notifier).state = {'s1'};

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.pin);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.afterTimeout);
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  test('graceExpired past the deadline wipes sessions the same way', () async {
    final container = buildContainer(SessionLocked(
      mood: LockMood.welcomeBack,
      gate: const AttemptGate(),
      openSessionCount: 3,
      lockDeadline: DateTime.now(),
    ));
    container.read(openSiteIdsProvider.notifier).state = {'s1', 's2', 's3'};

    container.read(sessionProvider.notifier).graceExpired();

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.afterTimeout);
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  test('graceExpired is a no-op once the user already unlocked', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));
    await container.read(sessionProvider.notifier).unlock('111111');

    container.read(sessionProvider.notifier).graceExpired();

    expect(container.read(sessionProvider), isA<SessionOpen>());
  });
}
