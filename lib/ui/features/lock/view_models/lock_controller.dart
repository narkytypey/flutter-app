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

  final ValueChanged<String> onSubmit;

  String _digits = '';

  LockPinEntry get value => LockPinEntry(filled: _digits.length);

  void onKey(String key) {
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
      onSubmit(pin);
    }
  }

  void reset() {
    _digits = '';
    notifyListeners();
  }
}
