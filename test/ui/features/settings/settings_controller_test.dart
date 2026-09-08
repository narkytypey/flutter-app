import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/vault.dart';
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

    expect(biometrics.keyPairGenerated, isTrue);
    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNotNull);
    expect(await container.read(settingsRepositoryProvider).getBool('biometrics_enabled'),
        isTrue);
  });

  test('disabling clears the in-memory ciphertext immediately', () async {
    await container.read(settingsControllerProvider).setBiometricsEnabled(true);

    await container.read(settingsControllerProvider).setBiometricsEnabled(false);

    expect(biometrics.keyPairGenerated, isFalse);
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
}
