import 'dart:typed_data';

/// Every key operation in the app. The implementation lives in Kotlin so that
/// Dart never holds a key-encrypting key, and so the Argon2id work happens off
/// the platform thread.
abstract interface class CryptoService {
  /// Argon2id, m = 64 MiB, t = 3, p = 2, 32-byte output.
  Future<Uint8List> deriveKek(String pin, Uint8List salt);

  /// AES-256-GCM. Returns null when the tag does not authenticate — which is
  /// the only way the app ever learns a PIN was wrong.
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped);

  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey);

  Future<Uint8List> randomBytes(int length);

  /// Deletes the device-bound Keystore key that wraps both slots at rest.
  /// After this, neither slot can ever be unwrapped again by anyone.
  Future<void> destroyDeviceKey();
}
