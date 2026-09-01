import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 3),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text('How sites will behave', style: T.stepTitle),
                      const SizedBox(height: 18),
                      Text(
                        'These apply to every site you add. You can change any '
                        'of them per site later.',
                        style: ui(size: 14, color: C.textMuted, height: 1.65),
                      ),
                      const SizedBox(height: 20),
                      for (final (title, detail) in _defaults)
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: C.line06)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✓', style: ui(size: 13, color: C.jade)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: T.body),
                                      const SizedBox(height: 3),
                                      Text(detail,
                                          style: ui(
                                              size: 12,
                                              color: C.textFaint,
                                              height: 1.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Add your first site',
                    tone: PillTone.primary,
                    height: 50,
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
