import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/vault_unlocker.dart';
import 'package:container/data/services/vault_store.dart';

import '../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  late Directory dir;
  late VaultStore store;
  late FakeCrypto crypto;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault-test');
    crypto = FakeCrypto();
    store = VaultStore(crypto, File('${dir.path}/meta.bin'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('a fresh device has no vaults', () async {
    expect(await store.exists, isFalse);
  });

  test('provisioning writes both slots, always', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);

    final slots = await store.slots();
    expect(slots.length, 2);
    expect(await store.exists, isTrue);
  });

  test('the two slots have different salts', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);

    final slots = await store.slots();
    expect(slots[0].salt, isNot(slots[1].salt));
  });

  test('both slots are the same size whether or not a decoy is real', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    final slots = await store.slots();
    expect(slots[0].wrappedKey.length, slots[1].wrappedKey.length);
    expect(slots[0].salt.length, slots[1].salt.length);
  });

  test('an unopenable slot cannot be unlocked by any PIN', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    final unlocker = VaultUnlocker(crypto);
    for (final pin in ['222222', '000000', '111112']) {
      final outcome = await unlocker.attempt(
        pin: pin,
        slots: await store.slots(),
        gate: const AttemptGate(),
        now: DateTime(2026),
      );
      expect(outcome, isA<Rejected>(), reason: 'PIN $pin should not open a slot');
    }
  });

  test('the attempt gate survives a restart', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.saveGate(const AttemptGate(failures: 3));

    final reopened = VaultStore(crypto, File('${dir.path}/meta.bin'));
    expect((await reopened.gate()).triesLeft, 2);
  });

  test('destroy removes every trace of key material', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    await store.destroy();

    expect(await store.exists, isFalse);
    expect(File('${dir.path}/meta.bin').existsSync(), isFalse);
  });

  // Change main PIN (user's ruling, 2026-09-30).

  test('rewrapping a slot moves it to the new PIN and keeps its data key', () async {
    final key = await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);
    final before = await store.slots();

    await store.rewrap(vault: VaultId.a, pin: '333333', dataKey: key);

    final unlocker = VaultUnlocker(crypto);
    Future<UnlockOutcome> attempt(String pin) async => unlocker.attempt(
        pin: pin, slots: await store.slots(), gate: const AttemptGate(), now: DateTime(2026));
    final opened = await attempt('333333') as Unlocked;
    expect(opened.vault, VaultId.a);
    expect(opened.dataKey, key);
    expect(await attempt('111111'), isA<Rejected>());
    expect((await attempt('222222') as Unlocked).vault, VaultId.b);

    final after = await store.slots();
    expect(after[0].salt, isNot(before[0].salt));
    expect(after[1].salt, before[1].salt);
    expect(after[1].wrappedKey, before[1].wrappedKey);
    expect(after[0].wrappedKey.length, before[0].wrappedKey.length);
  });

  test('rewrapping keeps the attempt counter', () async {
    final key = await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);
    await store.saveGate(const AttemptGate(failures: 2));
    await store.rewrap(vault: VaultId.a, pin: '333333', dataKey: key);
    expect((await store.gate()).failures, 2);
  });

  // Auto-lock is one setting for both vaults (user's ruling, 2026-10-01): the
  // lock screen names it before any unlock, so a per-vault value would let
  // the decoy's Settings contradict it.

  test('auto-lock is the default until one is chosen', () async {
    expect(await store.autoLock(), AutoLockPolicy.oneMinute);
    await store.provision(pin: '111111', vault: VaultId.a);
    expect(await store.autoLock(), AutoLockPolicy.oneMinute);
  });

  test('a chosen auto-lock survives every write to the slots and the counter', () async {
    final key = await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    await store.saveAutoLock(AutoLockPolicy.fifteenMinutes);
    await store.saveGate(const AttemptGate(failures: 1));
    await store.rewrap(vault: VaultId.a, pin: '333333', dataKey: key);
    await store.provision(pin: '222222', vault: VaultId.b);

    expect(await store.autoLock(), AutoLockPolicy.fifteenMinutes);
  });

  // meta.bin was truncated and rewritten in place: a crash mid-write lost
  // both vaults' wrapped keys.
  test('writes through a temp file renamed over meta.bin', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);
    await File('${dir.path}/meta.bin.tmp').writeAsString('{"half');

    await store.saveAutoLock(AutoLockPolicy.fiveMinutes);

    expect(File('${dir.path}/meta.bin.tmp').existsSync(), isFalse);
    expect(await store.autoLock(), AutoLockPolicy.fiveMinutes);
    expect((await store.slots()).length, 2);
  });

  test('destroy also removes a temp file a crash left behind', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await File('${dir.path}/meta.bin.tmp').writeAsString('{"a":{}}');

    await store.destroy();

    expect(File('${dir.path}/meta.bin').existsSync(), isFalse);
    expect(File('${dir.path}/meta.bin.tmp').existsSync(), isFalse);
  });

  // Each read the file, changed its own key and wrote it back, so the last
  // write dropped the others' changes.
  test('concurrent read-modify-writes all land', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    final other = VaultStore(crypto, File('${dir.path}/meta.bin'));

    await Future.wait([
      store.saveGate(AttemptGate(failures: 3)),
      other.saveAutoLock(AutoLockPolicy.fifteenMinutes),
      store.provision(pin: '222222', vault: VaultId.b),
    ]);

    expect((await store.gate()).failures, 3);
    expect(await store.autoLock(), AutoLockPolicy.fifteenMinutes);
    expect((await store.slots()).length, 2);
  });
}
