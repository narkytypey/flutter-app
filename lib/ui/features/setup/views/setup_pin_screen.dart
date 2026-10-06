import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../core/widgets/pin_layout.dart';
import '../../../core/widgets/step_progress.dart';

class SetupPinScreen extends StatelessWidget {
  const SetupPinScreen({
    super.key,
    required this.filled,
    required this.onKey,
    required this.onContinue,
    this.notice,
    this.error = false,
    this.showProgress = true,
  });

  final int filled;

  /// A line under the dots, for a PIN that was refused: 'Choose a different
  /// PIN' when it would also open the other vault (user's ruling,
  /// 2026-09-30). It never says why, so a coerced session learns nothing.
  final String? notice;

  /// Red dots: Change main PIN's confirmation did not match.
  final bool error;

  /// Setup's step bar. Change main PIN reuses this screen outside setup.
  final bool showProgress;
  final void Function(String) onKey;

  /// Null until six digits are entered.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.s5),
          child: PinLayout(
            crossAxisAlignment: CrossAxisAlignment.start,
            top: showProgress ? const StepProgress(step: 1) : null,
            message: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a PIN', style: T.stepTitle),
                const SizedBox(height: S.s3),
                Text(
                  'Six digits. It encrypts everything stored on this '
                  'device. There is no account and no way to recover it, '
                  'so pick something you will remember.',
                  style: T.bodyMuted,
                ),
                const SizedBox(height: S.s6),
                PinDots(filled: filled, error: error),
                if (notice != null) ...[
                  const SizedBox(height: S.s4),
                  Text(notice!, style: T.body.copyWith(color: C.danger)),
                ],
              ],
            ),
            keypad: PinKeypad(onKey: onKey),
            // The one jade action, once six digits are in; a neutral fill
            // with a text-2 label until then (text-3 never sits on raised).
            bottom: Padding(
              padding: const EdgeInsets.only(top: S.s5, bottom: S.s6),
              child: Material(
                color: onContinue == null ? C.button : C.jade,
                borderRadius: BorderRadius.circular(R.full),
                child: InkWell(
                  onTap: onContinue,
                  borderRadius: BorderRadius.circular(R.full),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: T.label.copyWith(
                          fontWeight: onContinue == null ? FontWeight.w500 : FontWeight.w600,
                          color: onContinue == null ? C.textMuted : C.onJade,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
