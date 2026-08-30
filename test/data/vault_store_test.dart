import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
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
}
