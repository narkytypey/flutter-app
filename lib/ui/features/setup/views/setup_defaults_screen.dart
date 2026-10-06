import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/step_progress.dart';

class SetupDefaultsScreen extends StatelessWidget {
  const SetupDefaultsScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  static const _defaults = [
    ('Each site gets its own storage',
        'Cookies and logins never cross between sites'),
    ('Camera, mic, location and clipboard blocked',
        'A site has to ask you each time it wants one'),
    ('Trackers, ads and WebRTC blocked',
        'Some sites may need this relaxed to work'),
    ('Nothing is sent anywhere', 'No account, no sync, no analytics'),
  ];

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
              const StepProgress(step: 3),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: S.s7),
                      Text('How sites will behave', style: T.stepTitle),
                      const SizedBox(height: S.s4),
                      Text(
                        'These apply to every site you add. You can change any '
                        'of them per site later.',
                        style: T.bodyMuted,
                      ),
                      const SizedBox(height: S.s5),
                      Group(
                        children: [
                          for (final (title, detail) in _defaults)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: S.s3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // A check is a fact, not a live state: text-1.
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: AppIcon(AppGlyph.check,
                                        size: 20, color: C.textPrimary),
                                  ),
                                  const SizedBox(width: S.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: T.rowTitle),
                                        const SizedBox(height: 2),
                                        Text(detail, style: T.sub),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: S.s4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: S.s4, bottom: S.s6),
                child: SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Add your first site',
                    tone: PillTone.primary,
                    onTap: onFinish,
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
