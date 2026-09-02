import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../setup/views/setup_decoy_screen.dart';
import '../../setup/views/setup_defaults_screen.dart';
import '../../setup/views/setup_pin_screen.dart';
import '../view_models/session_controller.dart';

enum _SetupStep { mainPin, decoyChoice, decoyPin, defaults }

/// Sequences `4a` → `4b` → (`4a` again, for the decoy PIN, if chosen) →
/// `5a`, then calls `SetupController.complete`. See the Ruling above for why
/// the decoy PIN step reuses `4a` rather than a screen that does not exist.
class SetupFlow extends ConsumerStatefulWidget {
  const SetupFlow({super.key});

  @override
  ConsumerState<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends ConsumerState<SetupFlow> {
  _SetupStep _step = _SetupStep.mainPin;
  String _mainPin = '';
  bool _decoyEnabled = false;
  String _decoyPin = '';
  bool _completing = false;

  void _appendMain(String key) => setState(() => _mainPin = _apply(_mainPin, key));
  void _appendDecoy(String key) => setState(() => _decoyPin = _apply(_decoyPin, key));

  String _apply(String digits, String key) {
    if (key == '⌫') {
      return digits.isEmpty ? digits : digits.substring(0, digits.length - 1);
    }
    if (digits.length >= 6) return digits;
    return digits + key;
  }

  Future<void> _finish() async {
    if (_completing) return;
    setState(() => _completing = true);
    await ref.read(setupControllerProvider).complete(
          mainPin: _mainPin,
          decoyPin: _decoyEnabled ? _decoyPin : null,
        );
    // No further setState: AppGate swaps this widget out once
    // SessionController's state becomes SessionOpen.
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _SetupStep.mainPin => SetupPinScreen(
          filled: _mainPin.length,
          onKey: _appendMain,
          onContinue: _mainPin.length == 6
              ? () => setState(() => _step = _SetupStep.decoyChoice)
              : null,
        ),
      _SetupStep.decoyChoice => SetupDecoyScreen(
          enabled: _decoyEnabled,
          onToggle: (v) => setState(() => _decoyEnabled = v),
          onContinue: () => setState(() =>
              _step = _decoyEnabled ? _SetupStep.decoyPin : _SetupStep.defaults),
          onSkip: () => setState(() {
            _decoyEnabled = false;
            _step = _SetupStep.defaults;
          }),
        ),
      _SetupStep.decoyPin => SetupPinScreen(
          filled: _decoyPin.length,
          onKey: _appendDecoy,
          onContinue: _decoyPin.length == 6
              ? () => setState(() => _step = _SetupStep.defaults)
              : null,
        ),
      _SetupStep.defaults => SetupDefaultsScreen(onFinish: _finish),
    };
  }
}
