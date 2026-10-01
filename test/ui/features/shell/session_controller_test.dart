import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/biometric_service.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show openSiteIdsProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

class FakeBiometricService implements BiometricService {
  bool available = true;
  bool unwrapSucceeds = true;

  /// The vaults that currently have a Keystore keypair, one alias each.
  final keyPairs = <VaultId>{};

  /// Which vault's key each [unwrap] was asked to use, in order.
  final unwrappedWith = <VaultId>[];

  /// Simulates a Keystore alias that's missing or was just invalidated by
  /// new biometric enrollment: [wrap] throws until [generateKeyPair] has
  /// been called for that vault, then succeeds — modeling
  /// `_rewrapIfEnabled`'s regenerate-and-retry self-heal.
  bool wrapThrowsUntilRegenerated = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> generateKeyPair(VaultId vault) async => keyPairs.add(vault);

  @override
  Future<Uint8List> wrap(VaultId vault, Uint8List dataKey) async {
    if (wrapThrowsUntilRegenerated && !keyPairs.contains(vault)) {
      throw Exception('alias missing');
    }
    return dataKey;
  }

  @override
  Future<Uint8List?> unwrap(VaultId vault, Uint8List wrapped) async {
    unwrappedWith.add(vault);
    return unwrapSucceeds ? wrapped : null;
  }

  @override
  Future<void> destroyKeyPair(VaultId vault) async => keyPairs.remove(vault);

  @override
  Future<void> destroyAllKeyPairs() async => keyPairs.clear();
}

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
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
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
    expect(session.biometricWrappedKey, isNull);
  });

  test('a vault unlocked with no workspaces opens with Personal', () async {
    // What a decoy set up with no sites looked like: `+ Add site` threw on
    // `workspaces.first`.
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider) as SessionOpen;
    final workspaces = await SqliteWorkspaceRepository(session.database).all();
    expect(workspaces.map((w) => w.name), ['Personal']);
  });

  test('a vault resumed with no workspaces opens with Personal', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.b,
        biometricWrappedKey: Uint8List.fromList([4, 5, 6]),
      )),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    final workspaces = await SqliteWorkspaceRepository(db).all();
    expect(workspaces.map((w) => w.name), ['Personal']);
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
    final container = buildContainer(
        SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));
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
    final container = buildContainer(
        SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));
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

  test('unlocking with biometrics already enabled for the vault re-wraps the data key',
      () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteSettingsRepository(db).setBool('biometrics_enabled', true);
    final biometrics = FakeBiometricService();

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(
          SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate())),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNotNull);
  });

  test(
      'a correct PIN still opens the vault when the biometric Keystore key is '
      'missing or invalidated, by regenerating it', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteSettingsRepository(db).setBool('biometrics_enabled', true);
    final biometrics = FakeBiometricService()..wrapThrowsUntilRegenerated = true;

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(
          SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate())),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
    expect(biometrics.keyPairs, {VaultId.a});
  });

  test('a decoy-PIN unlock re-wraps under the decoy vault\'s own key', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provision(pin: '222222', vault: VaultId.b);
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteSettingsRepository(db).setBool('biometrics_enabled', true);
    final biometrics = FakeBiometricService()..wrapThrowsUntilRegenerated = true;

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(
          SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate())),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).unlock('222222');

    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.vault, VaultId.b);
    expect(session.biometricWrappedKey, isNotNull);
    expect(biometrics.keyPairs, {VaultId.b});
  });

  test('a wrong PIN during welcomeBack keeps the pending biometric ciphertext',
      () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final wrapped = Uint8List.fromList([9, 9, 9]);
    final container = buildContainer(SessionLocked(
      mood: LockMood.welcomeBack,
      gate: await vaultStore.gate(),
      biometricVault: VaultId.a,
      biometricWrappedKey: wrapped,
    ));

    await container.read(sessionProvider.notifier).unlock('000000');

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.wrong);
    expect(session.biometricVault, VaultId.a);
    expect(session.biometricWrappedKey, wrapped);
  });

  test('returning within the grace period carries a pending biometric wrap forward',
      () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final wrapped = Uint8List.fromList([1, 2, 3]);
    final container = buildContainer(SessionOpen(
      vault: VaultId.a,
      database: db,
      dataKey: Uint8List(32),
      biometricWrappedKey: wrapped,
    ));

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.board);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.biometricVault, VaultId.a);
    expect(session.biometricWrappedKey, wrapped);
  });

  test('resumeWithBiometric reopens the vault without a PIN', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final biometrics = FakeBiometricService();
    final wrapped = Uint8List.fromList([4, 5, 6]);

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.a,
        biometricWrappedKey: wrapped,
      )),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
  });

  test('resumeWithBiometric unwraps with the key of the vault that backgrounded',
      () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final biometrics = FakeBiometricService();

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.b,
        biometricWrappedKey: Uint8List.fromList([4, 5, 6]),
      )),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    expect(biometrics.unwrappedWith, [VaultId.b]);
    expect((container.read(sessionProvider) as SessionOpen).vault, VaultId.b);
  });

  test('resumeWithBiometric does nothing when the prompt is cancelled or fails',
      () async {
    final biometrics = FakeBiometricService()..unwrapSucceeds = false;
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.a,
        biometricWrappedKey: Uint8List.fromList([4, 5, 6]),
      )),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    expect(container.read(sessionProvider), isA<SessionLocked>());
  });

  test('setBiometricWrapped updates an open session in place', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = buildContainer(
        SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));

    container
        .read(sessionProvider.notifier)
        .setBiometricWrapped(Uint8List.fromList([1]));

    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, Uint8List.fromList([1]));
  });

  test('setBiometricWrapped is a no-op once the vault has closed', () async {
    final container = buildContainer(
        const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate()));

    container
        .read(sessionProvider.notifier)
        .setBiometricWrapped(Uint8List.fromList([1]));

    expect(container.read(sessionProvider), isA<SessionLocked>());
  });

  // User's rulings, 2026-09-30 and 2026-10-01: the Auto-lock choice, one for
  // both vaults, decides 9b's window and 9c's line.

  test("the shared auto-lock sets 9b's deadline and 9c's line, not the vault's own row", () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    await vaultStore.saveAutoLock(AutoLockPolicy.fiveMinutes);
    // A row left by the per-vault build (2026-09-30) is ignored.
    Future<AppDatabase> vaultWithFiveMinutes() async {
      final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      await SqliteSettingsRepository(db).setString('auto_lock', AutoLockPolicy.fifteenMinutes.stored);
      return db;
    }

    for (final destination in ReturnDestination.values) {
      final container = ProviderContainer(overrides: [
        cryptoServiceProvider.overrideWithValue(crypto),
        vaultStoreProvider.overrideWithValue(vaultStore),
        documentsDirectoryProvider.overrideWithValue(dir),
        initialSessionProvider.overrideWithValue(
            SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate())),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        vaultOpenerProvider.overrideWithValue(
            ({required String path, required Uint8List dataKey}) => vaultWithFiveMinutes()),
      ]);
      addTearDown(container.dispose);
      await container.read(sessionProvider.notifier).unlock('111111');
      expect(container.read(sessionProvider.notifier).debugAutoLock, AutoLockPolicy.fiveMinutes);

      final before = DateTime.now();
      container.read(sessionProvider.notifier).debugHandleReturn(destination);
      final locked = container.read(sessionProvider) as SessionLocked;
      expect(locked.lockedAfter, AutoLockPolicy.fiveMinutes);
      if (destination == ReturnDestination.board) {
        final grace = locked.lockDeadline!.difference(before);
        expect(grace.inSeconds, inInclusiveRange(299, 301));
      }
    }
  });

  test('a changed auto-lock applies to the next return', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = buildContainer(
        SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));
    final controller = container.read(sessionProvider.notifier);
    expect(controller.debugAutoLock, AutoLockPolicy.oneMinute);

    controller.setAutoLock(AutoLockPolicy.fifteenMinutes);
    final before = DateTime.now();
    controller.debugHandleReturn(ReturnDestination.board);

    final locked = container.read(sessionProvider) as SessionLocked;
    expect(locked.lockDeadline!.difference(before).inMinutes, 15);
  });

  test('9c keeps the line of the auto-lock that fired when the grace runs out', () async {
    final container = buildContainer(SessionLocked(
      mood: LockMood.welcomeBack,
      gate: const AttemptGate(),
      lockDeadline: DateTime.now(),
      lockedAfter: AutoLockPolicy.fiveMinutes,
    ));
    container.read(sessionProvider.notifier).graceExpired();
    final locked = container.read(sessionProvider) as SessionLocked;
    expect(locked.mood, LockMood.afterTimeout);
    expect(locked.lockedAfter, AutoLockPolicy.fiveMinutes);
  });
}
