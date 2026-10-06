import 'package:flutter/material.dart';

import '../../../../domain/services/panic_service.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/centered_scroll.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/pill_button.dart';

class PanicScreen extends StatelessWidget {
  const PanicScreen({super.key, required this.report, required this.onUnlock});

  final PanicReport report;
  final VoidCallback onUnlock;

  static const _lines = [
    ('WEBVIEWS', 'DESTROYED'),
    ('EPHEMERAL DATA', 'WIPED'),
    ('MEMORY', 'CLEARED'),
  ];

  @override
  Widget build(BuildContext context) {
    // Panic is not a different colour (restyle v2 §8): the page, with the
    // status words in text-1 and no jade, since nothing here is live.
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: CenteredScroll(
          padding: const EdgeInsets.symmetric(horizontal: S.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: C.danger, width: 1.5),
                ),
                child: AppIcon(AppGlyph.panic, size: 20, color: C.danger),
              ),
              const SizedBox(height: S.s6),
              Text('Everything closed',
                  textAlign: TextAlign.center, style: T.sheetTitle),
              const SizedBox(height: S.s2),
              Text(
                '${report.sessionsDestroyed} '
                '${report.sessionsDestroyed == 1 ? 'session' : 'sessions'} destroyed, temporary '
                'storage wiped, app locked.',
                textAlign: TextAlign.center,
                style: T.bodyMuted,
              ),
              const SizedBox(height: S.s6),
              Group(
                children: [
                  for (final (label, state) in _lines)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: S.s3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(label, style: T.sectionLabel),
                            ),
                            const SizedBox(width: S.s3),
                            Flexible(
                              child: Text(state,
                                  textAlign: TextAlign.end,
                                  style: T.sectionLabel
                                      .copyWith(color: C.textPrimary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: S.s6),
              PillButton(
                label: 'Unlock',
                padding: const EdgeInsets.symmetric(horizontal: S.s7),
                onTap: onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
