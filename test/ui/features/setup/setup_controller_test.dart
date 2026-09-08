import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/vault_unlocker.dart';
import 'package:container/ui/features/setup/view_models/setup_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  late FakeCrypto crypto;
  final opened = <String, AppDatabase>{};
  final sessions = <({VaultId vault, AppDatabase database, Uint8List dataKey})>[];

  Future<AppDatabase> fakeOpen({required String path, required Uint8List dataKey}) async {
    final db =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    opened[path] = db;
    return db;
  }

  SetupController controller() => SetupController(
        vaultStore: vaultStore,
        openVault: fakeOpen,
        pathFor: (vault) => '${dir.path}/${vault.name}.db',
        openSession: (
                {required VaultId vault,
                required AppDatabase database,
                required Uint8List dataKey}) =>
            sessions.add((vault: vault, database: database, dataKey: dataKey)),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup-test');
    crypto = FakeCrypto();
    vaultStore = VaultStore(crypto, File('${dir.path}/meta.bin'));
    opened.clear();
    sessions.clear();
  });

  tearDown(() async {
    for (final db in opened.values) {
      await db.close();
    }
    await dir.delete(recursive: true);
  });

  test('completing without a decoy still provisions both slots, one unopenable',
      () async {
    await controller().complete(mainPin: '111111');

    final slots = await vaultStore.slots();
    expect(slots.length, 2);
    expect(slots[0].wrappedKey.length, slots[1].wrappedKey.length,
        reason: 'the unopened slot must not be a different size');
  });

  test('completing without a decoy hands off a seeded vault A', () async {
    await controller().complete(mainPin: '111111');

    expect(sessions, hasLength(1));
    expect(sessions.single.vault, VaultId.a);
    final workspaces =
        await SqliteWorkspaceRepository(sessions.single.database).all();
    expect(workspaces, isNotEmpty, reason: 'seedIfEmpty should have run');
  });

  test('a decoy PIN provisions vault B and does not hand it off', () async {
    await controller().complete(mainPin: '111111', decoyPin: '222222');

    expect(sessions, hasLength(1));
    expect(sessions.single.vault, VaultId.a);
    expect(opened.keys, containsAll(['${dir.path}/a.db', '${dir.path}/b.db']));
  });

  test('both PINs actually unlock their own vault afterwards', () async {
    await controller().complete(mainPin: '111111', decoyPin: '222222');

    final unlocker = VaultUnlocker(crypto);
    final slots = await vaultStore.slots();

    final mainOutcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: DateTime(2026));
    expect((mainOutcome as Unlocked).vault, VaultId.a);

    final decoyOutcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: DateTime(2026));
    expect((decoyOutcome as Unlocked).vault, VaultId.b);
  });
}
