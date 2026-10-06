import 'package:flutter/material.dart';

import '../../../../domain/models/lock_state.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../core/widgets/pin_layout.dart';

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
    this.biometricAvailable = false,
    this.lockedAfter = AutoLockPolicy.oneMinute,
  });

  final LockMood mood;
  final int filled;
  final void Function(String key) onKey;
  final VoidCallback onBiometric;
  final int triesLeft;
  final int openSessions;
  final int secondsUntilLock;
  final bool biometricAvailable;

  /// Names the Auto-lock choice in `9c`'s line.
  final AutoLockPolicy lockedAfter;

  bool get _wrong => mood == LockMood.wrong;

  /// Resume-only: the fingerprint prompt only ever appears for a vault this
  /// session already opened once with a PIN and is now re-confirming
  /// during the welcome-back grace window — never for a cold lock. See the
  /// biometric-unlock design spec's "Decision" section for why.
  bool get _showBiometric => mood == LockMood.welcomeBack && biometricAvailable;

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
                _mark(),
                const SizedBox(height: S.s6),
                ..._headline(),
                const SizedBox(height: S.s6),
                PinDots(filled: filled, error: _wrong),
                ..._footnote(),
              ],
            ),
            keypad: PinKeypad(onKey: onKey),
            bottom: _showBiometric ? _biometric() : null,
          ),
        ),
      ),
    );
  }

  // The case mark (restyle v2 §6): text-1, since nothing on a lock screen is
  // live; danger after a wrong PIN.
  Widget _mark() => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.input),
          border: _wrong
              ? Border.all(color: C.danger, width: 1.5)
              : Border.all(color: C.line),
        ),
        child: AppIcon(AppGlyph.vault, size: 20, color: _wrong ? C.danger : C.textPrimary),
      );

  /// A count set in Mono inside a sentence of words (spec §1.5); the rest of
  /// the line's style is inherited.
  static TextSpan _count(int n) =>
      TextSpan(text: '$n', style: TextStyle(fontFamily: T.value.fontFamily));

  // Centred, so a line that wraps at a large text scale stays centred too.
  List<Widget> _headline() => switch (mood) {
        LockMood.wrong => [
            Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Wrong PIN · '),
                  _count(triesLeft),
                  TextSpan(text: ' ${triesLeft == 1 ? 'try' : 'tries'} left'),
                ]),
                textAlign: TextAlign.center,
                style: T.stepTitle.copyWith(color: C.danger)),
          ],
        LockMood.welcomeBack => [
            Text('Welcome back',
                textAlign: TextAlign.center,
                style: T.stepTitle),
            const SizedBox(height: S.s2),
            Text.rich(
                TextSpan(children: [
                  _count(openSessions),
                  TextSpan(
                      text: ' ${openSessions == 1 ? 'session' : 'sessions'} still open '
                          '· locks in '),
                  _count(secondsUntilLock),
                  const TextSpan(text: 's'),
                ]),
                textAlign: TextAlign.center,
                style: T.bodyMuted),
          ],
        LockMood.normal || LockMood.afterTimeout => [
            Text('Enter your PIN',
                textAlign: TextAlign.center,
                style: T.stepTitle),
          ],
      };

  List<Widget> _footnote() => switch (mood) {
        LockMood.wrong => [
            const SizedBox(height: S.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'After 5 wrong tries the app waits 30 seconds before accepting '
                'another.',
                textAlign: TextAlign.center,
                style: T.bodyMuted,
              ),
            ),
          ],
        LockMood.afterTimeout => [
            const SizedBox(height: S.s5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: S.s3),
              decoration: BoxDecoration(
                color: C.surface,
                border: Border.all(color: C.line),
                borderRadius: BorderRadius.circular(R.group),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lockedAfter.lockedLine,
                      style: T.bodyMuted),
                  const SizedBox(height: S.s1),
                  Text(
                    'Ephemeral sessions were closed and wiped. Saved sites '
                    'will reopen where you left them.',
                    style: T.sub.copyWith(color: C.textFaint),
                  ),
                ],
              ),
            ),
          ],
        LockMood.normal || LockMood.welcomeBack => const [],
      };

  Widget _biometric() => Padding(
        padding: const EdgeInsets.only(top: S.s6, bottom: S.s7),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBiometric,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The one affirmative action on `9b` when it is offered.
                AppIcon(AppGlyph.fingerprint, size: 28, color: C.jade),
                const SizedBox(height: S.s2),
                Text('Use fingerprint', style: T.sub),
              ],
            ),
          ),
        ),
      );
}
