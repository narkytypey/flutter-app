import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/attempt_gate.dart';
import '../../domain/models/vault.dart';
import '../../domain/services/crypto_service.dart';

/// Persists the two vault slots and the attempt counter.
///
/// The file always contains exactly two slots of identical shape. A device
/// with no decoy configured is byte-indistinguishable from one that has a
/// decoy the owner is refusing to open — which is the whole point, because a
/// missing second slot would prove there is nothing to hide.
class VaultStore {
  const VaultStore(this._crypto, this._file);

  final CryptoService _crypto;
  final File _file;

  static const saltLength = 16;
  static const dataKeyLength = 32;

  Future<bool> get exists => _file.exists();

  Future<List<VaultSlot>> slots() async {
    final data = await _read();
    return [
      _slotFrom(data['a'] as Map<String, Object?>),
      _slotFrom(data['b'] as Map<String, Object?>),
    ];
  }

  Future<AttemptGate> gate() async {
    if (!await exists) return const AttemptGate();
    final data = await _read();
    final until = data['lockedUntil'] as int?;
    return AttemptGate(
      failures: (data['failures'] as int?) ?? 0,
      lockedUntil:
          until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  Future<void> saveGate(AttemptGate gate) async {
    final data = await _read();
    data['failures'] = gate.failures;
    data['lockedUntil'] = gate.lockedUntil?.millisecondsSinceEpoch;
    await _write(data);
  }

  /// Creates [vault]'s slot and returns its new data key.
  Future<Uint8List> provision({
    required String pin,
    required VaultId vault,
  }) async {
    final salt = await _crypto.randomBytes(saltLength);
    final dataKey = await _crypto.randomBytes(dataKeyLength);
    final kek = await _crypto.deriveKek(pin, salt);
    final wrapped = await _crypto.wrap(kek, dataKey);

    final data = await _read();
    data[vault.name] = {
      'salt': base64Encode(salt),
      'wrapped': base64Encode(wrapped),
    };
    await _write(data);
    return dataKey;
  }

  /// Fills [vault]'s slot with a real slot whose PIN is generated, used once
  /// and never stored. The result is a slot nothing can ever open, and that
  /// nothing can distinguish from one that can.
  Future<void> provisionUnopenable(VaultId vault) async {
    final throwaway = base64Encode(await _crypto.randomBytes(24));
    await provision(pin: throwaway, vault: vault);
  }

  Future<void> destroy() async {
    if (await _file.exists()) {
      // Overwrite before unlinking; the file is small and this costs nothing.
      final length = await _file.length();
      await _file.writeAsBytes(await _crypto.randomBytes(length), flush: true);
      await _file.delete();
    }
    await _crypto.destroyDeviceKey();
  }

  VaultSlot _slotFrom(Map<String, Object?> raw) => VaultSlot(
        salt: base64Decode(raw['salt']! as String),
        wrappedKey: base64Decode(raw['wrapped']! as String),
      );

  Future<Map<String, Object?>> _read() async {
    if (!await _file.exists()) return <String, Object?>{};
    return jsonDecode(await _file.readAsString()) as Map<String, Object?>;
  }

  Future<void> _write(Map<String, Object?> data) =>
      _file.writeAsString(jsonEncode(data), flush: true);
}
