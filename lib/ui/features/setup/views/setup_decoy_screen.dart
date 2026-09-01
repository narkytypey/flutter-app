import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A second PIN, if you want one', style: T.stepTitle),
                    const SizedBox(height: 16),
                    Text(
                      'If someone makes you unlock the app, this PIN opens a '
                      'plain board with only the sites you choose. Nothing on '
                      'it hints that anything else exists.',
                      style: ui(size: 14, color: C.textMuted, height: 1.65),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: C.line08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ColoredBox(
                            color: C.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Set up a decoy PIN', style: T.body),
                                  AppToggle(value: enabled, onChanged: onToggle),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          ColoredBox(
                            color: C.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Sites to show', style: T.body),
                                      const SizedBox(height: 3),
                                      Text('Pick after setup',
                                          style: ui(
                                              size: 11.5, color: C.textFaint)),
                                    ],
                                  ),
                                  Text('›', style: ui(size: 14, color: C.textFaint)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PillButton(
                        label: 'Continue',
                        tone: PillTone.primary,
                        height: 50,
                        onTap: onContinue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onSkip,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text('Skip for now',
                              style: ui(size: 14, color: C.textMuted)),
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
