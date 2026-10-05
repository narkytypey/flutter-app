import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/centered_scroll.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showProgress) const StepProgress(step: 1),
              Expanded(
                child: CenteredScroll(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose a PIN', style: T.stepTitle),
                    const SizedBox(height: 14),
                    Text(
                      'Six digits. It encrypts everything stored on this '
                      'device. There is no account and no way to recover it, '
                      'so pick something you will remember.',
                      style: ui(size: 14, color: C.textMuted, height: 1.65),
                    ),
                    const SizedBox(height: 26),
                    PinDots(filled: filled, error: error),
                    if (notice != null) ...[
                      const SizedBox(height: 16),
                      Text(notice!, style: ui(size: 14, color: C.danger)),
                    ],
                  ],
                  ),
                ),
              ),
              PinKeypad(onKey: onKey),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 26),
                child: Material(
                  color: onContinue == null ? C.button : C.jade,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    onTap: onContinue,
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          'Continue',
                          style: ui(
                            size: 15,
                            weight: onContinue == null ? 500 : 600,
                            color: onContinue == null ? C.textDim : C.bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
