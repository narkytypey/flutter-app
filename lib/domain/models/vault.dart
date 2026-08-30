import 'dart:typed_data';

import 'attempt_gate.dart';

/// Which store. The two are peers; neither is "the real one" as far as any
/// code below the UI is concerned.
enum VaultId { a, b }

/// What is persisted per vault: a salt and a wrapped data key. Both slots are
/// always present and always the same size, so their contents reveal nothing
/// about whether a decoy has been configured.
class VaultSlot {
  const VaultSlot({required this.salt, required this.wrappedKey});

  final Uint8List salt;
  final Uint8List wrappedKey;
}

sealed class UnlockOutcome {
  const UnlockOutcome();
}

class Unlocked extends UnlockOutcome {
  const Unlocked({required this.vault, required this.dataKey, required this.gate});

  final VaultId vault;
  final Uint8List dataKey;
  final AttemptGate gate;
}

class Rejected extends UnlockOutcome {
  const Rejected(this.gate);

  final AttemptGate gate;
}

class Throttled extends UnlockOutcome {
  const Throttled(this.remaining);

  final Duration remaining;
}
