import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lock/view_models/lock_controller.dart';
import '../../setup/views/setup_pin_screen.dart';
import '../view_models/providers.dart';
import 'decoy_resync_pin_screen.dart';

enum _Step { current, replacement, confirm }

/// Settings' "Change main PIN" (user's ruling, 2026-09-30): the open vault's
/// current PIN on the lock screen's keypad, then the new PIN twice on setup's
/// PIN screen, without its step bar. Only this vault's key slot changes; its
/// store is not re-encrypted. No new copy but "Choose a different PIN", for
/// a new PIN that would also open the other vault. A confirmation that does
/// not match starts the new PIN again with red dots and no words.
class ChangePinRoute extends ConsumerStatefulWidget {
  const ChangePinRoute({super.key});

  @override
  ConsumerState<ChangePinRoute> createState() => _ChangePinRouteState();
}

class _ChangePinRouteState extends ConsumerState<ChangePinRoute> {
  late final LockController _currentEntry;
  _Step _step = _Step.current;
  String _current = '';
  String _replacement = '';
  String _typed = '';
  bool _wrong = false;
  bool _mismatch = false;
  bool _clash = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = LockController(onSubmit: _verify)..addListener(_onChanged);
  }

  @override
  void dispose() {
    _currentEntry
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  SettingsController get _settings => ref.read(settingsControllerProvider);

  Future<void> _verify(String pin) async {
    final outcome = await _settings.verifyCurrentPin(pin);
    if (!mounted) return;
    setState(() {
      if (outcome is ChangePinVerified) {
        _current = pin;
        _step = _Step.replacement;
      } else {
        _wrong = true;
      }
    });
  }

  void _key(String key) => setState(() {
        _mismatch = false;
        _clash = false;
        if (key == '⌫') {
          if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
        } else if (_typed.length < 6) {
          _typed += key;
        }
      });

  Future<void> _continue() async {
    if (_step == _Step.replacement) {
      setState(() {
        _replacement = _typed;
        _typed = '';
        _step = _Step.confirm;
      });
      return;
    }
    if (_typed != _replacement) {
      setState(() {
        _typed = '';
        _replacement = '';
        _mismatch = true;
        _step = _Step.replacement;
      });
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await _settings.changePin(current: _current, replacement: _replacement);
    if (!mounted) return;
    switch (outcome) {
      case ChangePinDone():
        Navigator.pop(context);
      case ChangePinClash():
        setState(() {
          _busy = false;
          _typed = '';
          _replacement = '';
          _clash = true;
          _step = _Step.replacement;
        });
      case ChangePinVerified():
      case ChangePinRejected():
      case ChangePinThrottled():
        // The current PIN no longer checks out (the gate closed meanwhile):
        // start again from it.
        setState(() {
          _busy = false;
          _typed = '';
          _replacement = '';
          _current = '';
          _wrong = true;
          _step = _Step.current;
        });
    }
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
        _Step.current => DecoyResyncPinScreen(
            title: 'Enter your PIN',
            filled: _currentEntry.value.filled,
            error: _wrong,
            onKey: (key) {
              // A PIN is still being checked: LockController ignores keys.
              if (_currentEntry.busy) return;
              if (_wrong) setState(() => _wrong = false);
              _currentEntry.onKey(key);
            },
          ),
        _Step.replacement || _Step.confirm => SetupPinScreen(
            // A fresh screen per step, so nothing carries over between them.
            key: ValueKey(_step),
            filled: _typed.length,
            onKey: _key,
            onContinue: _typed.length == 6 && !_busy ? _continue : null,
            notice: _clash ? 'Choose a different PIN' : null,
            error: _mismatch,
            showProgress: false,
          ),
      };
}
