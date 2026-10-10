import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/services/vault_unlocker.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show containerEngineProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;
import '../shell/session_controller_test.dart' show FakeBiometricService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late FakeBiometricService biometrics;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings-controller-test');
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    biometrics = FakeBiometricService();
    container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(FakeCrypto()),
      vaultStoreProvider.overrideWithValue(
          VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'))),
      documentsDirectoryProvider.overrideWithValue(dir),
      biometricServiceProvider.overrideWithValue(biometrics),
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => dir.delete(recursive: true));

  test('enabling biometrics generates a keypair, wraps the open session\'s '
      'data key, and persists the setting', () async {
    await container.read(settingsControllerProvider).setBiometricsEnabled(true);

    expect(biometrics.keyPairs, {VaultId.a});
    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNotNull);
    expect(await container.read(settingsRepositoryProvider).getBool('biometrics_enabled'),
        isTrue);
  });

  test('disabling clears the in-memory ciphertext immediately', () async {
    await container.read(settingsControllerProvider).setBiometricsEnabled(true);

    await container.read(settingsControllerProvider).setBiometricsEnabled(false);

    expect(biometrics.keyPairs, isEmpty);
    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNull);
    expect(await container.read(settingsRepositoryProvider).getBool('biometrics_enabled'),
        isFalse);
  });

  test('biometricsEnabledProvider reflects the persisted setting', () async {
    expect(await container.read(biometricsEnabledProvider.future), isFalse);

    await container.read(settingsControllerProvider).setBiometricsEnabled(true);
    container.invalidate(biometricsEnabledProvider);

    expect(await container.read(biometricsEnabledProvider.future), isTrue);
  });

  group('in the decoy vault', () {
    setUp(() {
      container = ProviderContainer(overrides: [
        cryptoServiceProvider.overrideWithValue(FakeCrypto()),
        vaultStoreProvider.overrideWithValue(
            VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'))),
        documentsDirectoryProvider.overrideWithValue(dir),
        biometricServiceProvider.overrideWithValue(biometrics),
        initialSessionProvider.overrideWithValue(
            SessionOpen(vault: VaultId.b, database: db, dataKey: Uint8List(32))),
      ]);
      addTearDown(container.dispose);
    });

    // Both vaults used to share one Keystore alias, so this deleted the real
    // vault's key too.
    test('turning biometrics off leaves the other vault\'s key alone', () async {
      biometrics.keyPairs.addAll({VaultId.a, VaultId.b});

      await container.read(settingsControllerProvider).setBiometricsEnabled(false);

      expect(biometrics.keyPairs, {VaultId.a});
    });

    test('turning biometrics on makes a key for this vault only', () async {
      await container.read(settingsControllerProvider).setBiometricsEnabled(true);

      expect(biometrics.keyPairs, {VaultId.b});
      final session = container.read(sessionProvider) as SessionOpen;
      expect(session.biometricWrappedKey, isNotNull);
    });
  });

  group('resyncDecoyVault', () {
    setUp(() async {
      final vaultStore =
          VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'));
      await vaultStore.provision(pin: '111111', vault: VaultId.a);
      await vaultStore.provision(pin: '222222', vault: VaultId.b);
      container = ProviderContainer(overrides: [
        cryptoServiceProvider.overrideWithValue(FakeCrypto()),
        vaultStoreProvider.overrideWithValue(vaultStore),
        documentsDirectoryProvider.overrideWithValue(dir),
        biometricServiceProvider.overrideWithValue(biometrics),
        vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi),
        ),
        initialSessionProvider.overrideWithValue(
            SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
      ]);
      addTearDown(container.dispose);
    });

    test('a correct decoy PIN runs the sync and resets the gate', () async {
      await SqliteWorkspaceRepository(db).upsert(const Workspace(
          id: 'ws', name: 'Personal', markerIndex: 0,
          storageRule: StorageRule.keep, showInDecoy: true));
      await SqliteSiteRepository(db).upsert(Site(
          id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
          url: 'https://news.example.com', profileId: newProfileId(),
          showInDecoy: true));

      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('222222');

      expect(outcome, isA<DecoyResyncSucceeded>());
    });

    test('the main PIN is rejected the same as a wrong one', () async {
      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('111111');

      expect(outcome, isA<DecoyResyncRejected>());
    });

    test('a non-matching PIN is rejected and counts a failure', () async {
      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('000000');

      expect(outcome, isA<DecoyResyncRejected>());
      final gate = await container.read(vaultStoreProvider).gate();
      expect(gate.failures, 1);
    });

    group('against a decoy store that persists', () {
      late FakeContainerEngine engine;
      late List<AppDatabase> opened;
      late ProviderContainer persistent;

      setUp(() {
        engine = FakeContainerEngine();
        opened = [];
        persistent = ProviderContainer(overrides: [
          cryptoServiceProvider.overrideWithValue(FakeCrypto()),
          vaultStoreProvider.overrideWithValue(container.read(vaultStoreProvider)),
          documentsDirectoryProvider.overrideWithValue(dir),
          biometricServiceProvider.overrideWithValue(biometrics),
          containerEngineProvider.overrideWithValue(engine),
          vaultOpenerProvider.overrideWithValue(
            ({required String path, required Uint8List dataKey}) async {
              final database =
                  await AppDatabase.open(path: path, factory: databaseFactoryFfi);
              opened.add(database);
              return database;
            },
          ),
          initialSessionProvider.overrideWithValue(
              SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
        ]);
        addTearDown(persistent.dispose);
      });

      test("wipes the profile of every decoy site the sync removed", () async {
        await SqliteWorkspaceRepository(db).upsert(const Workspace(
            id: 'ws', name: 'Personal', markerIndex: 0,
            storageRule: StorageRule.keep, showInDecoy: true));
        await SqliteSiteRepository(db).upsert(Site(
            id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
            url: 'https://news.example.com', profileId: newProfileId(),
            showInDecoy: true));
        final controller = persistent.read(settingsControllerProvider);
        await controller.resyncDecoyVault('222222');
        expect(engine.wiped, isEmpty);
        final decoy = await AppDatabase.open(
            path: vaultDatabasePath(dir, VaultId.b), factory: databaseFactoryFfi);
        final decoyProfile =
            (await SqliteSiteRepository(decoy).byId('s1'))!.profileId;
        await decoy.close();

        await SqliteSiteRepository(db).upsert(
            (await SqliteSiteRepository(db).byId('s1'))!.copyWith(showInDecoy: false));
        final outcome = await controller.resyncDecoyVault('222222');

        expect(outcome, isA<DecoyResyncSucceeded>());
        expect(engine.wiped, [decoyProfile]);
        expect(opened.every((d) => !d.db.isOpen), isTrue);
      });

      test('closes the decoy store even when the sync throws', () async {
        final decoy = await AppDatabase.open(
            path: vaultDatabasePath(dir, VaultId.b), factory: databaseFactoryFfi);
        await decoy.db.execute('DROP TABLE workspaces');
        await decoy.close();

        await expectLater(
            persistent.read(settingsControllerProvider).resyncDecoyVault('222222'),
            throwsA(anything));

        expect(opened, hasLength(1));
        expect(opened.single.db.isOpen, isFalse);
      });
    });

    test('five wrong attempts throttle the sixth', () async {
      for (var i = 0; i < 5; i++) {
        await container.read(settingsControllerProvider).resyncDecoyVault('000000');
      }

      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('000000');

      expect(outcome, isA<DecoyResyncThrottled>());
    });
  });

  test('choosing an auto-lock saves it once for both vaults and applies it now', () async {
    await container.read(settingsControllerProvider).setAutoLock(AutoLockPolicy.fiveMinutes);

    expect(await container.read(vaultStoreProvider).autoLock(), AutoLockPolicy.fiveMinutes);
    expect(await container.read(settingsRepositoryProvider).getString('auto_lock'), isNull);
    expect(await container.read(autoLockProvider.future), AutoLockPolicy.fiveMinutes);
    expect(container.read(sessionProvider.notifier).debugAutoLock, AutoLockPolicy.fiveMinutes);
  });

  test("the other vault's Settings shows the same auto-lock", () async {
    await container.read(settingsControllerProvider).setAutoLock(AutoLockPolicy.fifteenMinutes);

    final decoyDb = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final decoy = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(FakeCrypto()),
      vaultStoreProvider.overrideWithValue(container.read(vaultStoreProvider)),
      documentsDirectoryProvider.overrideWithValue(dir),
      biometricServiceProvider.overrideWithValue(biometrics),
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.b, database: decoyDb, dataKey: Uint8List(32))),
    ]);
    addTearDown(decoy.dispose);

    expect(await decoy.read(autoLockProvider.future), AutoLockPolicy.fifteenMinutes);
  });

  test('the auto-lock shown is read again once another vault opens', () async {
    expect(await container.read(autoLockProvider.future), AutoLockPolicy.oneMinute);

    // Written behind Settings' back, as a panic and a new setup would.
    await container.read(vaultStoreProvider).saveAutoLock(AutoLockPolicy.fiveMinutes);
    final next = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    container
        .read(sessionProvider.notifier)
        .completeSetup(vault: VaultId.a, database: next, dataKey: Uint8List(32));

    expect(await container.read(autoLockProvider.future), AutoLockPolicy.fiveMinutes);
  });

  // Change main PIN (user's ruling, 2026-09-30).

  group('changePin', () {
    late VaultStore store;
    late Uint8List keyA;

    setUp(() async {
      store = container.read(vaultStoreProvider);
      keyA = await store.provision(pin: '111111', vault: VaultId.a);
      await store.provision(pin: '222222', vault: VaultId.b);
    });

    Future<UnlockOutcome> tryPin(String pin) async => VaultUnlocker(FakeCrypto()).attempt(
        pin: pin, slots: await store.slots(), gate: const AttemptGate(), now: DateTime.now());

    test('step 1: only this vault\'s current PIN is verified, and a miss costs an attempt',
        () async {
      final controller = container.read(settingsControllerProvider);
      expect(await controller.verifyCurrentPin('111111'), isA<ChangePinVerified>());
      expect(await controller.verifyCurrentPin('222222'), isA<ChangePinRejected>());
      final missed = await controller.verifyCurrentPin('999999');
      expect((missed as ChangePinRejected).triesLeft, 3);
      expect((await store.gate()).failures, 2);
    });

    test('the right current PIN and a free new one move this vault to the new PIN', () async {
      final outcome = await container.read(settingsControllerProvider).changePin(
          current: '111111', replacement: '333333');

      expect(outcome, isA<ChangePinDone>());
      final opened = await tryPin('333333') as Unlocked;
      expect(opened.vault, VaultId.a);
      expect(opened.dataKey, keyA);
      expect(await tryPin('111111'), isA<Rejected>());
      expect((await tryPin('222222') as Unlocked).vault, VaultId.b);
    });

    test('a wrong current PIN is a failed attempt, and nothing changes', () async {
      final outcome = await container.read(settingsControllerProvider).changePin(
          current: '999999', replacement: '333333');

      expect(outcome, isA<ChangePinRejected>());
      expect((outcome as ChangePinRejected).triesLeft, 4);
      expect((await store.gate()).failures, 1);
      expect((await tryPin('111111') as Unlocked).vault, VaultId.a);
    });

    test("the other vault's PIN is not this vault's current PIN", () async {
      final outcome = await container.read(settingsControllerProvider).changePin(
          current: '222222', replacement: '333333');

      expect(outcome, isA<ChangePinRejected>());
      expect((await tryPin('111111') as Unlocked).vault, VaultId.a);
      expect((await tryPin('222222') as Unlocked).vault, VaultId.b);
    });

    /// It would open only whichever vault is tried first. Refusing it tells
    /// the person the PIN opens something, so it costs an attempt, exactly
    /// as trying it on the lock screen would.
    test("a new PIN that opens the other vault is refused, and costs an attempt", () async {
      final outcome = await container.read(settingsControllerProvider).changePin(
          current: '111111', replacement: '222222');

      expect(outcome, isA<ChangePinClash>());
      expect((await store.gate()).failures, 1);
      expect((await tryPin('111111') as Unlocked).vault, VaultId.a);
      expect((await tryPin('222222') as Unlocked).vault, VaultId.b);
    });

    /// Verifying the current PIN never resets the attempt counter: if it did,
    /// "verify, then try a PIN as the new one" would leave it at one failure
    /// each round, and the lockout would never come.
    test('rounds of clashing new PINs reach the lockout', () async {
      final controller = container.read(settingsControllerProvider);
      for (var round = 0; round < 5; round++) {
        expect(await controller.verifyCurrentPin('111111'), isA<ChangePinVerified>());
        expect(await controller.changePin(current: '111111', replacement: '222222'),
            isA<ChangePinClash>());
      }
      expect(await controller.verifyCurrentPin('111111'), isA<ChangePinThrottled>());
    });

    test('a locked-out gate refuses before trying anything', () async {
      await store.saveGate(AttemptGate(failures: 5, lockedUntil: DateTime.now().add(const Duration(seconds: 30))));

      final outcome = await container.read(settingsControllerProvider).changePin(
          current: '111111', replacement: '333333');

      expect(outcome, isA<ChangePinThrottled>());
      expect((await tryPin('111111') as Unlocked).vault, VaultId.a);
    });
  });

  // User's ruling 2026-10-10: flipping face down is the only panic, so a
  // vault that never set the switch has it on.
  test('the flip switch is saved in the open vault, on until turned off', () async {
    expect(await container.read(panicOnFlipProvider.future), isTrue);

    await container.read(settingsControllerProvider).setPanicOnFlip(false);

    expect(await container.read(settingsRepositoryProvider).getBool('panic_on_flip'), isFalse);
    expect(await container.read(panicOnFlipProvider.future), isFalse);

    await container.read(settingsControllerProvider).setPanicOnFlip(true);

    expect(await container.read(panicOnFlipProvider.future), isTrue);
  });
}

