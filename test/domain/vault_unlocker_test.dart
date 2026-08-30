import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/crypto_service.dart';
import 'package:container/domain/services/vault_unlocker.dart';

/// A fake in which a KEK is just the PIN and salt concatenated, and a wrapped
/// key unwraps only if it was wrapped under the same KEK.
class FakeCrypto implements CryptoService {
  FakeCrypto();

  final List<String> derivations = [];

  @override
  Future<Uint8List> deriveKek(String pin, Uint8List salt) async {
    derivations.add('$pin/${salt.join(",")}');
    return Uint8List.fromList('$pin|${salt.join(",")}'.codeUnits);
  }

  @override
  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey) async =>
      Uint8List.fromList([...kek, 0, ...dataKey]);

  @override
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped) async {
    final sep = wrapped.indexOf(0);
    if (sep == -1) return null;
    final usedKek = wrapped.sublist(0, sep);
    if (usedKek.length != kek.length) return null;
    for (var i = 0; i < kek.length; i++) {
      if (usedKek[i] != kek[i]) return null;
    }
    return Uint8List.fromList(wrapped.sublist(sep + 1));
  }

  @override
  Future<Uint8List> randomBytes(int length) async =>
      Uint8List.fromList(List.filled(length, 7));

  @override
  Future<void> destroyDeviceKey() async {}
}

final _now = DateTime(2026, 8, 30, 9, 10);
final _saltA = Uint8List.fromList([1, 1]);
final _saltB = Uint8List.fromList([2, 2]);
final _keyA = Uint8List.fromList([10, 11, 12]);
final _keyB = Uint8List.fromList([20, 21, 22]);

Future<List<VaultSlot>> _slots(FakeCrypto crypto,
    {String pinA = '111111', String? pinB = '222222'}) async {
  final kekA = await crypto.deriveKek(pinA, _saltA);
  final slotA = VaultSlot(salt: _saltA, wrappedKey: await crypto.wrap(kekA, _keyA));

  if (pinB == null) {
    // No decoy configured: the slot still exists, filled with bytes that no
    // PIN unwraps.
    return [slotA, VaultSlot(salt: _saltB, wrappedKey: Uint8List.fromList([9, 9, 9]))];
  }
  final kekB = await crypto.deriveKek(pinB, _saltB);
  return [slotA, VaultSlot(salt: _saltB, wrappedKey: await crypto.wrap(kekB, _keyB))];
}

void main() {
  late FakeCrypto crypto;
  late VaultUnlocker unlocker;

  setUp(() {
    crypto = FakeCrypto();
    unlocker = VaultUnlocker(crypto);
  });

  test('the main PIN opens vault A with its data key', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Unlocked>());
    expect((outcome as Unlocked).vault, VaultId.a);
    expect(outcome.dataKey, _keyA);
  });

  test('the decoy PIN opens vault B, with a different key', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: _now);

    expect((outcome as Unlocked).vault, VaultId.b);
    expect(outcome.dataKey, _keyB);
    expect(outcome.dataKey, isNot(_keyA));
  });

  test('a wrong PIN is rejected and spends a try', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '999999', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Rejected>());
    expect((outcome as Rejected).gate.triesLeft, 4);
  });

  test('every attempt derives a KEK for both slots, even a successful one',
      () async {
    // Returning early on the first match would let unlock time reveal which
    // slot matched, and therefore that two slots are live.
    final slots = await _slots(crypto);
    crypto.derivations.clear();

    await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: _now);

    expect(crypto.derivations.length, 2);
  });

  test('an unconfigured decoy slot is indistinguishable from a wrong PIN',
      () async {
    final slots = await _slots(crypto, pinB: null);
    final outcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Rejected>());
  });

  test('a throttled gate refuses without deriving anything', () async {
    final slots = await _slots(crypto);
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(_now);
    }
    crypto.derivations.clear();

    final outcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: gate, now: _now);

    expect(outcome, isA<Throttled>());
    expect((outcome as Throttled).remaining, const Duration(seconds: 30));
    expect(crypto.derivations, isEmpty);
  });

  test('a successful unlock resets the gate', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '111111',
        slots: slots,
        gate: const AttemptGate(failures: 3),
        now: _now);

    expect(outcome, isA<Unlocked>());
    expect((outcome as Unlocked).gate.triesLeft, 5);
  });
}
