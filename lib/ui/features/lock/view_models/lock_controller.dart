import 'dart:async';

import 'package:flutter/foundation.dart';

/// How many of the six PIN digits have been typed so far.
class LockPinEntry {
  const LockPinEntry({this.filled = 0});

  final int filled;
}

/// Accumulates the six digits typed on any lock-shaped screen (`3a`, `4c`,
/// `9b`, `9c` — all one `LockBody`) and calls [onSubmit] once, with the
/// buffer already cleared for whatever comes next.
///
/// Deliberately knows nothing about vaults, PINs being right or wrong, or
/// Riverpod. Task 8's `LockScreen` is the only thing that decides what a
/// finished six digits means.
class LockController extends ChangeNotifier {
  LockController({required this.onSubmit});

  /// May return a future: until it completes, every key is ignored, so a
  /// second six digits typed while the first are still being checked never
  /// reaches [onSubmit] (each submit is one attempt against the gate).
  final FutureOr<void> Function(String pin) onSubmit;

  String _digits = '';
  bool _busy = false;

  /// True while a submitted PIN's future has not completed.
  bool get busy => _busy;

  LockPinEntry get value => LockPinEntry(filled: _digits.length);

  void onKey(String key) {
    if (_busy) return;
    if (key == '⌫') {
      if (_digits.isEmpty) return;
      _digits = _digits.substring(0, _digits.length - 1);
    } else if (_digits.length < 6) {
      _digits += key;
    } else {
      return;
    }
    notifyListeners();

    if (_digits.length == 6) {
      final pin = _digits;
      reset();
      final result = onSubmit(pin);
      if (result is Future<void>) {
        _busy = true;
        result.whenComplete(() => _busy = false);
      }
    }
  }

  void reset() {
    _digits = '';
    notifyListeners();
  }
}
