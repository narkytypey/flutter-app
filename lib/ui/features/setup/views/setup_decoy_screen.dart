import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/centered_scroll.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/step_progress.dart';

/// The only screen in the app that ever names the decoy. After this the
/// feature is never mentioned again, which is what makes `3b` work.
class SetupDecoyScreen extends StatelessWidget {
  const SetupDecoyScreen({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.onContinue,
    required this.onSkip,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 2),
              Expanded(
                child: CenteredScroll(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A second PIN, if you want one', style: T.stepTitle),
                    const SizedBox(height: S.s4),
                    Text(
                      'If someone makes you unlock the app, this PIN opens a '
                      'plain board with only the sites you choose. Nothing on '
                      'it hints that anything else exists.',
                      style: T.bodyMuted,
                    ),
                    const SizedBox(height: S.s6),
                    Group(
                      padding: EdgeInsets.zero,
                      children: [
                        // A tap anywhere on the row toggles it, not only
                        // on the switch.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onToggle(!enabled),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: S.s4, vertical: S.s3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('Set up a decoy PIN', style: T.rowTitle),
                                  ),
                                  const SizedBox(width: S.s3),
                                  AppToggle(value: enabled, onChanged: onToggle),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 72),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: S.s4, vertical: S.s3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Sites to show', style: T.rowTitle),
                                      const SizedBox(height: 2),
                                      Text('Pick after setup', style: T.sub),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: S.s3),
                                const AppIcon(AppGlyph.forward, size: 18, color: C.chevron),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: S.s4, bottom: S.s6),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PillButton(
                        label: 'Continue',
                        tone: PillTone.primary,
                        onTap: onContinue,
                      ),
                    ),
                    const SizedBox(height: S.s2),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onSkip,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Center(
                          child: Text('Skip for now',
                              style: T.label.copyWith(
                                  color: C.textMuted, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
