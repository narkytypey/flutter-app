import 'package:flutter/services.dart';

class SecureWindow {
  const SecureWindow();

  static const _channel = MethodChannel('com.mono.container/window');

  /// FLAG_SECURE is set natively for the process lifetime; this only keeps the
  /// recents label neutral.
  Future<void> neutraliseRecents() => _channel.invokeMethod('neutraliseRecents');
}
