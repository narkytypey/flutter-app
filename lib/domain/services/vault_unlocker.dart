import 'dart:typed_data';

import '../models/attempt_gate.dart';
import '../models/vault.dart';
import 'crypto_service.dart';

/// Turns an entered PIN into an open vault, or into a rejection.
///
/// Two properties matter more than the code:
///
/// 1. Every slot is evaluated on every attempt, in a fixed order, before a
///    result is chosen. Stopping at the first match would make a successful
///    unlock of vault A measurably faster than one of vault B, which tells an
///    observer that two slots are live.
/// 2. There is no lookup from PIN to vault. A PIN is tried against every slot
///    and the one that unwraps wins. This is why a PIN for a vault that was
///    never configured is indistinguishable from a typo.
class VaultUnlocker {
  const VaultUnlocker(this._crypto);

  final CryptoService _crypto;

  Future<UnlockOutcome> attempt({
    required String pin,
    required List<VaultSlot> slots,
    required AttemptGate gate,
    required DateTime now,
  }) async {
    if (gate.lockedAt(now)) return Throttled(gate.remainingAt(now));

    VaultId? matched;
    Uint8List? matchedKey;

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final kek = await _crypto.deriveKek(pin, slot.salt);
      final dataKey = await _crypto.unwrap(kek, slot.wrappedKey);

      // Deliberately no `break`: see the class comment.
      if (dataKey != null && matched == null) {
        matched = VaultId.values[i];
        matchedKey = dataKey;
      }
    }

    if (matched == null) return Rejected(gate.recordFailure(now));

    return Unlocked(vault: matched, dataKey: matchedKey!, gate: gate.reset());
  }
}
