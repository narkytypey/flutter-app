import 'dart:typed_data';

import '../models/vault.dart';

/// Every biometric-gated key operation. Kotlin owns the actual Keystore
/// keypairs and the `BiometricPrompt` UI, mirroring `CryptoService`'s split
/// between Dart contract and platform implementation.
///
/// Each vault has its own keypair, so nothing one vault's session does to its
/// key — turning biometrics off, regenerating it — can touch the other's.
abstract interface class BiometricService {
  /// Hardware present and at least one biometric enrolled.
  Future<bool> isAvailable();

  /// (Re)creates [vault]'s Keystore keypair, discarding any previous one —
  /// any ciphertext wrapped under the old keypair becomes unusable.
  Future<void> generateKeyPair(VaultId vault);

  /// Public-key encrypt under [vault]'s keypair. Never shows a prompt.
  Future<Uint8List> wrap(VaultId vault, Uint8List dataKey);

  /// Shows the system biometric prompt for [vault]'s keypair. Null on
  /// cancel, failed match, or an invalidated key — never throws for any of
  /// those, the same convention `CryptoService.unwrap` uses for a wrong PIN.
  Future<Uint8List?> unwrap(VaultId vault, Uint8List wrapped);

  Future<void> destroyKeyPair(VaultId vault);

  /// Panic's step: every vault's keypair, whichever session is open.
  Future<void> destroyAllKeyPairs();
}
