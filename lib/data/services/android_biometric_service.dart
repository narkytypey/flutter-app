import 'package:flutter/services.dart';

import '../../domain/models/vault.dart';
import '../../domain/services/biometric_service.dart';

class AndroidBiometricService implements BiometricService {
  const AndroidBiometricService();

  static const _channel = MethodChannel('com.mono.container/biometric');

  @override
  Future<bool> isAvailable() async =>
      (await _channel.invokeMethod<bool>('isAvailable')) ?? false;

  @override
  Future<void> generateKeyPair(VaultId vault) =>
      _channel.invokeMethod('generateKeyPair', {'vault': vault.name});

  @override
  Future<Uint8List> wrap(VaultId vault, Uint8List dataKey) async {
    final result = await _channel.invokeMethod<Uint8List>(
        'wrap', {'vault': vault.name, 'dataKey': dataKey});
    return result!;
  }

  @override
  Future<Uint8List?> unwrap(VaultId vault, Uint8List wrapped) {
    // A null reply covers cancel, failed match, and an invalidated key alike
    // — same convention CryptoService.unwrap uses for a wrong PIN.
    return _channel.invokeMethod<Uint8List>(
        'unwrap', {'vault': vault.name, 'wrapped': wrapped});
  }

  @override
  Future<void> destroyKeyPair(VaultId vault) =>
      _channel.invokeMethod('destroyKeyPair', {'vault': vault.name});

  @override
  Future<void> destroyAllKeyPairs() => _channel.invokeMethod('destroyAllKeyPairs');
}
