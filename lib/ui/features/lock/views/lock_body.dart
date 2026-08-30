import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';

/// The four states of the lock screen: `3a`, `4c`, `9b`, `9c`.
///
/// They are one screen, and building them as four files would let their copy
/// and geometry drift. Note that none of them mentions vaults, decoys or a
/// second PIN — the lock must give no hint that anything else exists.
enum LockMood { normal, wrong, welcomeBack, afterTimeout }

class LockBody extends StatelessWidget {
  const LockBody({
    super.key,
    required this.mood,
    required this.filled,
    required this.onKey,
    required this.onBiometric,
    this.triesLeft = 5,
    this.openSessions = 0,
    this.secondsUntilLock = 0,
  });

  final LockMood mood;
  final int filled;
  final void Function(String key) onKey;
  final VoidCallback onBiometric;
  final int triesLeft;
  final int openSessions;
  final int secondsUntilLock;

  bool get _wrong => mood == LockMood.wrong;

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
                    _mark(),
                    const SizedBox(height: 26),
                    ..._headline(),
                    const SizedBox(height: 26),
                    PinDots(filled: filled, error: _wrong),
                    ..._footnote(),
                  ],
                ),
              ),
              PinKeypad(onKey: onKey),
              _biometric(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark() => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _wrong ? C.danger.withValues(alpha: 0.3) : C.line12,
          ),
        ),
        child: Text('◇',
            style: ui(size: 17, color: _wrong ? C.danger : C.jade)),
      );

  List<Widget> _headline() => switch (mood) {
        LockMood.wrong => [
            Text('Wrong PIN · $triesLeft tries left',
                style: ui(size: 14, color: C.danger)),
          ],
        LockMood.welcomeBack => [
            Text('Welcome back', style: ui(size: 15, color: C.textSecondary)),
            const SizedBox(height: 8),
            Text('$openSessions sessions still open · locks in ${secondsUntilLock}s',
                style: ui(size: 12.5, color: C.textFaint)),
          ],
        LockMood.normal || LockMood.afterTimeout => [
            Text('Enter your PIN', style: ui(size: 14, color: C.textMuted)),
          ],
      };

  List<Widget> _footnote() => switch (mood) {
        LockMood.wrong => [
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'After 5 wrong tries the app waits 30 seconds before accepting '
                'another.',
                textAlign: TextAlign.center,
                style: ui(size: 12.5, color: C.textFaint, height: 1.6),
              ),
            ),
          ],
        LockMood.afterTimeout => [
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.sheet,
                border: Border.all(color: C.line07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Locked after 1 minute in the background',
                      style: ui(size: 12.5, color: C.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    'Ephemeral sessions were closed and wiped. Saved sites '
                    'will reopen where you left them.',
                    style: ui(size: 12, color: C.textDim, height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        LockMood.normal || LockMood.welcomeBack => const [],
      };

  Widget _biometric() => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 30),
        child: GestureDetector(
          onTap: _wrong ? null : onBiometric,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('☉',
                  style: ui(size: 24, color: _wrong ? C.knobOff : C.jade)),
              const SizedBox(height: 8),
              Text(
                _wrong ? 'Fingerprint unavailable' : 'Use fingerprint',
                style: ui(size: 12, color: _wrong ? C.textDim : C.textFaint),
              ),
            ],
          ),
        ),
      );
}
