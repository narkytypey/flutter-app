import 'package:flutter/services.dart';

import '../../domain/services/crypto_service.dart';

class AndroidCryptoService implements CryptoService {
  const AndroidCryptoService();

  static const _channel = MethodChannel('com.mono.container/crypto');

  @override
  Future<Uint8List> deriveKek(String pin, Uint8List salt) async {
    final result = await _channel
        .invokeMethod<Uint8List>('deriveKek', {'pin': pin, 'salt': salt});
    return result!;
  }

  @override
  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey) async {
    final result = await _channel
        .invokeMethod<Uint8List>('wrap', {'kek': kek, 'dataKey': dataKey});
    return result!;
  }

  @override
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped) {
    // A null reply is the expected negative result, not an error.
    return _channel
        .invokeMethod<Uint8List>('unwrap', {'kek': kek, 'wrapped': wrapped});
  }

  @override
  Future<Uint8List> randomBytes(int length) async {
    final result =
        await _channel.invokeMethod<Uint8List>('randomBytes', {'length': length});
    return result!;
  }

  @override
  Future<void> destroyDeviceKey() => _channel.invokeMethod('destroyDeviceKey');
}
