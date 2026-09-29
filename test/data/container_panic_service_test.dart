import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/container_panic_service.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../domain/vault_unlocker_test.dart' show FakeCrypto;
import '../ui/features/shell/session_controller_test.dart' show FakeBiometricService;

Site _site(String id) => Site(
      id: id,
      workspaceId: 'w1',
      name: id,
      monogram: 'X',
      url: 'https://example.com/$id',
      profileId: newProfileId(),
    );

void main() {
  test('every container is destroyed before anything else is', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    final order = <String>[];
    final service = ContainerPanicService(
      engine: engine,
      closeDatabase: () async => order.add('close:${engine.wipedAll}'),
      destroyVaults: () async => order.add('destroy:${engine.wipedAll}'),
      destroyBiometricKeys: () async => order.add('biometric:${engine.wipedAll}'),
    );

    await service.trigger();

    expect(engine.wipedAll, isTrue);
    // All three later steps observed the profiles as already gone.
    expect(order, ['close:true', 'destroy:true', 'biometric:true']);
  });

  test('live sessions are closed before the profiles are wiped', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKeys: () async {},
    ).trigger();

    expect(engine.closed, ['a', 'b']);
  });

  test('the report counts what was destroyed', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));
    await engine.open(_site('c'));

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKeys: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 3);
  });

  // What the device actually did (2026-09-28): WebView refuses to delete a
  // profile the process has loaded, `wipeAll` threw, and panic stopped
  // before a single key was destroyed — failing open, with the vault intact.
  test('a wipe that throws still destroys the database, vaults and key', () async {
    final engine = _WipeAllThrows();
    await engine.open(_site('a'));
    final destroyed = <String>[];

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async => destroyed.add('database'),
      destroyVaults: () async => destroyed.add('vaults'),
      destroyBiometricKeys: () async => destroyed.add('biometric'),
    ).trigger();

    expect(destroyed, ['database', 'vaults', 'biometric']);
    expect(report.sessionsDestroyed, 1);
  });

  test('a close that throws still wipes, and still destroys the keys', () async {
    final engine = _CloseThrows();
    await engine.open(_site('a'));
    await engine.open(_site('b'));
    var vaultsDestroyed = false;

    await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async => vaultsDestroyed = true,
      destroyBiometricKeys: () async {},
    ).trigger();

    expect(engine.wipedAll, isTrue);
    expect(vaultsDestroyed, isTrue);
  });

  test('panic on a cold app with nothing open still completes', () async {
    final engine = FakeContainerEngine();
    var destroyed = false;

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async => destroyed = true,
      destroyBiometricKeys: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 0);
    expect(destroyed, isTrue);
  });

  test('panic from the decoy vault destroys both vaults\' biometric keys',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('panic-provider-test');
    addTearDown(() => dir.delete(recursive: true));
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final biometrics = FakeBiometricService()
      ..keyPairs.addAll({VaultId.a, VaultId.b});
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(FakeContainerEngine()),
      vaultStoreProvider.overrideWithValue(
          VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'))),
      documentsDirectoryProvider.overrideWithValue(dir),
      biometricServiceProvider.overrideWithValue(biometrics),
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.b, database: db, dataKey: Uint8List(32))),
    ]);
    addTearDown(container.dispose);

    await container.read(panicServiceProvider).trigger();

    expect(biometrics.keyPairs, isEmpty);
  });
}

class _WipeAllThrows extends FakeContainerEngine {
  @override
  Future<void> wipeAll() async => throw PlatformException(
      code: 'engine', message: 'Cannot delete in-use profile 0a396e81');
}

class _CloseThrows extends FakeContainerEngine {
  @override
  Future<void> close(String siteId) async =>
      throw PlatformException(code: 'engine', message: 'close failed');
}
