import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/attempt_gate.dart';
import '../../domain/models/lock_state.dart';
import '../../domain/models/vault.dart';
import '../../domain/services/crypto_service.dart';

/// Persists the two vault slots, the attempt counter and the Auto-lock choice.
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

  Future<void> saveGate(AttemptGate gate) => _update((data) {
        data['failures'] = gate.failures;
        data['lockedUntil'] = gate.lockedUntil?.millisecondsSinceEpoch;
      });

  /// Settings' Auto-lock, one choice for both vaults (user's ruling,
  /// 2026-10-01). It lives here, outside either vault, because the lock screen
  /// names it before any unlock (`9b`'s countdown, `9c`'s line): a per-vault
  /// choice would let the decoy's Settings contradict what the lock screen
  /// said, which would show there is another vault.
  Future<AutoLockPolicy> autoLock() async {
    if (!await exists) return AutoLockPolicy.oneMinute;
    return AutoLockPolicy.fromStored((await _read())['autoLock'] as String?);
  }

  Future<void> saveAutoLock(AutoLockPolicy policy) =>
      _update((data) => data['autoLock'] = policy.stored);

  /// Creates [vault]'s slot and returns its new data key.
  Future<Uint8List> provision({
    required String pin,
    required VaultId vault,
  }) async {
    final salt = await _crypto.randomBytes(saltLength);
    final dataKey = await _crypto.randomBytes(dataKeyLength);
    final kek = await _crypto.deriveKek(pin, salt);
    final wrapped = await _crypto.wrap(kek, dataKey);

    await _update((data) => data[vault.name] = {
          'salt': base64Encode(salt),
          'wrapped': base64Encode(wrapped),
        });
    return dataKey;
  }

  /// Change main PIN: wraps [vault]'s existing [dataKey] under [pin], with a
  /// fresh salt. The vault's store is not re-encrypted, since its key is
  /// unchanged; the other slot and the attempt counter are left as they are.
  Future<void> rewrap({
    required VaultId vault,
    required String pin,
    required Uint8List dataKey,
  }) async {
    final salt = await _crypto.randomBytes(saltLength);
    final kek = await _crypto.deriveKek(pin, salt);
    final wrapped = await _crypto.wrap(kek, dataKey);

    await _update((data) => data[vault.name] = {
          'salt': base64Encode(salt),
          'wrapped': base64Encode(wrapped),
        });
  }

  /// Fills [vault]'s slot with a real slot whose PIN is generated, used once
  /// and never stored. The result is a slot nothing can ever open, and that
  /// nothing can distinguish from one that can.
  Future<void> provisionUnopenable(VaultId vault) async {
    final throwaway = base64Encode(await _crypto.randomBytes(24));
    await provision(pin: throwaway, vault: vault);
  }

  Future<void> destroy() async {
    await _serialized(() async {
      // A temp file a crash left mid-write holds a copy of the slots too.
      for (final file in [_file, _temp]) {
        if (await file.exists()) {
          // Overwrite before unlinking; the file is small and this costs
          // nothing.
          final length = await file.length();
          await file.writeAsBytes(await _crypto.randomBytes(length), flush: true);
          await file.delete();
        }
      }
    });
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

  /// Written beside [_file], then renamed over it: rename within one
  /// directory is atomic, so a crash mid-write leaves the old file whole
  /// instead of a truncated one that has lost both vaults' wrapped keys.
  File get _temp => File('${_file.path}.tmp');

  Future<void> _write(Map<String, Object?> data) async {
    final temp = _temp;
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(_file.path);
  }

  /// A read-modify-write of the file, run one at a time per file so two
  /// concurrent callers (the attempt gate, Auto-lock, a re-wrap) cannot each
  /// read the old contents and have the second write drop the first's change.
  Future<void> _update(void Function(Map<String, Object?> data) change) =>
      _serialized(() async {
        final data = await _read();
        change(data);
        await _write(data);
      });

  /// Per file path, not per instance: the store is `const` and more than one
  /// instance may point at the same file.
  static final _queues = <String, Future<void>>{};

  Future<T> _serialized<T>(Future<T> Function() body) {
    final key = _file.absolute.path;
    final result = (_queues[key] ?? Future<void>.value()).then((_) => body());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_queues[key], tail)) _queues.remove(key);
    });
    _queues[key] = tail;
    return result;
  }
}
