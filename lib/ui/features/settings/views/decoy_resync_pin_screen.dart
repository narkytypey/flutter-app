import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';

/// Verifies the decoy PIN before `SettingsController.resyncDecoyVault` runs.
///
/// Deliberately built from the low-level `PinDots`/`PinKeypad` widgets
/// rather than `LockBody` — `LockBody` is coupled to the app-wide
/// `SessionController` lock state machine (resume moods, grace timers,
/// biometric resume), none of which applies to this one-off check
/// triggered from inside Settings. Says nothing about vaults, real or
/// decoy, in its copy — same instinct `LockBody` already follows.
class DecoyResyncPinScreen extends StatelessWidget {
  const DecoyResyncPinScreen({
    super.key,
    required this.filled,
    required this.error,
    required this.onKey,
  });

  final int filled;
  final bool error;
  final void Function(String key) onKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Enter the decoy PIN',
                        style: ui(size: 14, color: C.textMuted)),
                    const SizedBox(height: 26),
                    PinDots(filled: filled, error: error),
                    if (error) ...[
                      const SizedBox(height: 20),
                      Text('Wrong PIN', style: ui(size: 14, color: C.danger)),
                    ],
                  ],
                ),
              ),
              PinKeypad(onKey: onKey),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
