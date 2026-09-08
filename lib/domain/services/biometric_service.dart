import 'dart:typed_data';

/// Every biometric-gated key operation. Kotlin owns the actual Keystore
/// keypair and the `BiometricPrompt` UI, mirroring `CryptoService`'s split
/// between Dart contract and platform implementation.
abstract interface class BiometricService {
  /// Hardware present and at least one biometric enrolled.
  Future<bool> isAvailable();

  /// (Re)creates the device's Keystore keypair, discarding any previous one
  /// — any ciphertext wrapped under the old keypair becomes unusable.
  Future<void> generateKeyPair();

  /// Public-key encrypt. Never shows a prompt.
  Future<Uint8List> wrap(Uint8List dataKey);

  /// Shows the system biometric prompt. Null on cancel, failed match, or an
  /// invalidated key — never throws for any of those, the same convention
  /// `CryptoService.unwrap` uses for a wrong PIN.
  Future<Uint8List?> unwrap(Uint8List wrapped);

  Future<void> destroyKeyPair();
}
