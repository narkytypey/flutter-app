import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../core/widgets/pin_layout.dart';

/// Verifies the decoy PIN before `SettingsController.resyncDecoyVault` runs.
///
/// Deliberately built from the low-level `PinDots`/`PinKeypad` widgets
/// rather than `LockBody` — `LockBody` is coupled to the app-wide
/// `SessionController` lock state machine (resume moods, grace timers,
/// biometric resume), none of which applies to this one-off check
/// triggered from inside Settings. Says nothing about vaults, real or
/// decoy, in its copy — same instinct `LockBody` already follows.
///
/// Change main PIN's first step reuses it with [title] `Enter your PIN`,
/// the lock screen's own line.
class DecoyResyncPinScreen extends StatelessWidget {
  const DecoyResyncPinScreen({
    super.key,
    required this.filled,
    required this.error,
    required this.onKey,
    this.title = 'Enter the decoy PIN',
  });

  final String title;
  final int filled;
  final bool error;
  final void Function(String key) onKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.s5),
          child: PinLayout(
            message: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, textAlign: TextAlign.center, style: T.stepTitle),
                const SizedBox(height: S.s6),
                PinDots(filled: filled, error: error),
                if (error) ...[
                  const SizedBox(height: S.s5),
                  Text('Wrong PIN', style: T.body.copyWith(color: C.danger)),
                ],
              ],
            ),
            keypad: PinKeypad(onKey: onKey),
            bottom: const SizedBox(height: S.s5),
          ),
        ),
      ),
    );
  }
}
