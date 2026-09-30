import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/services/flip_service.dart';

/// `FlipPanicPlugin` over `com.mono.container/flip`: `start` and `stop` go
/// down, `flipped` comes back up.
class AndroidFlipService implements FlipService {
  AndroidFlipService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'flipped') _flips.add(null);
    });
  }

  static const _channel = MethodChannel('com.mono.container/flip');
  final _flips = StreamController<void>.broadcast();

  @override
  Stream<void> get flips => _flips.stream;

  @override
  Future<bool> start() async => (await _channel.invokeMethod<bool>('start')) ?? false;

  @override
  Future<void> stop() => _channel.invokeMethod('stop');
}
