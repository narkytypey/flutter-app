import 'package:flutter/services.dart';

import '../../domain/services/biometric_service.dart';

class AndroidBiometricService implements BiometricService {
  const AndroidBiometricService();

  static const _channel = MethodChannel('com.mono.container/biometric');

  @override
  Future<bool> isAvailable() async =>
      (await _channel.invokeMethod<bool>('isAvailable')) ?? false;

  @override
  Future<void> generateKeyPair() => _channel.invokeMethod('generateKeyPair');

  @override
  Future<Uint8List> wrap(Uint8List dataKey) async {
    final result =
        await _channel.invokeMethod<Uint8List>('wrap', {'dataKey': dataKey});
    return result!;
  }

  @override
  Future<Uint8List?> unwrap(Uint8List wrapped) {
    // A null reply covers cancel, failed match, and an invalidated key alike
    // — same convention CryptoService.unwrap uses for a wrong PIN.
    return _channel.invokeMethod<Uint8List>('unwrap', {'wrapped': wrapped});
  }

  @override
  Future<void> destroyKeyPair() => _channel.invokeMethod('destroyKeyPair');
}
