import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/settings_repository_sqlite.dart';
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
  bool keyPairGenerated = false;

  /// Simulates a Keystore alias that's missing or was just invalidated by
  /// new biometric enrollment: [wrap] throws until [generateKeyPair] has
  /// been called, then succeeds — modeling `_rewrapIfEnabled`'s regenerate
  /// -and-retry self-heal.
  bool wrapThrowsUntilRegenerated = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> generateKeyPair() async => keyPairGenerated = true;

  @override
  Future<Uint8List> wrap(Uint8List dataKey) async {
    if (wrapThrowsUntilRegenerated && !keyPairGenerated) {
      throw Exception('alias missing');
    }
    return dataKey;
  }

  @override
  Future<Uint8List?> unwrap(Uint8List wrapped) async =>
      unwrapSucceeds ? wrapped : null;

  @override
  Future<void> destroyKeyPair() async => keyPairGenerated = false;
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
    expect(biometrics.keyPairGenerated, isTrue);
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
}
