import 'package:flutter/material.dart';

import '../../../../domain/services/panic_service.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
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
    return Scaffold(
      backgroundColor: C.bgPanic,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: C.danger.withValues(alpha: 0.35)),
                ),
                child: Text('◉', style: ui(size: 16, color: C.danger)),
              ),
              const SizedBox(height: 30),
              Text('Everything closed', style: ui(size: 18, weight: 600)),
              const SizedBox(height: 10),
              Text(
                '${report.sessionsDestroyed} sessions destroyed, temporary '
                'storage wiped, app locked.',
                textAlign: TextAlign.center,
                style: ui(size: 13, color: C.textMuted, height: 1.6),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: C.line07),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (label, state) in _lines) ...[
                      if (label != _lines.first.$1) const SizedBox(height: 1),
                      ColoredBox(
                        color: C.sheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: ui(size: 11.5, color: C.textMuted)),
                              Text(state,
                                  style: ui(
                                      size: 11.5, weight: 500, color: C.jade)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              PillButton(
                label: 'Unlock',
                height: 48,
                onTap: onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
