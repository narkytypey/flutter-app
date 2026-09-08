import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lock/view_models/lock_controller.dart';
import '../view_models/providers.dart';
import 'decoy_resync_pin_screen.dart';

/// Pushed from `SettingsScreen`'s "Re-sync decoy now" row. Owns the PIN
/// buffer (via the same [LockController] the real lock screen uses — it
/// "knows nothing about vaults, PINs being right or wrong, or Riverpod",
/// per its own doc comment, so it is directly reusable here) and calls
/// [SettingsController.resyncDecoyVault], mapping the result to
/// [DecoyResyncPinScreen]'s `error` flag or a success SnackBar + pop.
class DecoyResyncRoute extends ConsumerStatefulWidget {
  const DecoyResyncRoute({super.key});

  @override
  ConsumerState<DecoyResyncRoute> createState() => _DecoyResyncRouteState();
}

class _DecoyResyncRouteState extends ConsumerState<DecoyResyncRoute> {
  late final LockController _pin;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _pin = LockController(onSubmit: _submit)..addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _pin
      ..removeListener(_onPinChanged)
      ..dispose();
    super.dispose();
  }

  void _onPinChanged() => setState(() {});

  Future<void> _submit(String pin) async {
    final outcome =
        await ref.read(settingsControllerProvider).resyncDecoyVault(pin);
    if (!mounted) return;

    switch (outcome) {
      case DecoyResyncSucceeded():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Decoy vault synced')));
        Navigator.pop(context);
      case DecoyResyncRejected():
      case DecoyResyncThrottled():
        setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoyResyncPinScreen(
      filled: _pin.value.filled,
      error: _error,
      onKey: (key) {
        if (_error) setState(() => _error = false);
        _pin.onKey(key);
      },
    );
  }
}
