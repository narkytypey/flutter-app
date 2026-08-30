import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/page_skeleton.dart';

/// Spec `8c` — the page freezes and the decision surfaces at the top,
/// instead of a dialog stealing focus from a page the user was reading.
class TunnelDroppedScreen extends StatelessWidget {
  const TunnelDroppedScreen({
    super.key,
    required this.host,
    required this.droppedAgoLabel,
    required this.onReconnect,
    required this.onCloseAndWipe,
  });

  final String host;
  final String droppedAgoLabel;
  final VoidCallback onReconnect;
  final VoidCallback onCloseAndWipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: Text('‹', style: TextStyle(fontSize: 16, color: C.icon))),
                  ),
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: C.danger.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(host, style: ui(size: 11.5, color: C.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: Text('⟳', style: TextStyle(fontSize: 14, color: C.icon))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1517),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.danger.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⛌', style: TextStyle(fontSize: 13, color: C.danger)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tunnel dropped', style: ui(size: 14.5, weight: 600)),
                              const SizedBox(height: 5),
                              Text(
                                'The page is paused. Nothing further has been requested '
                                'since the connection failed $droppedAgoLabel.',
                                style: ui(size: 12.5, height: 1.6, color: C.dangerMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Reconnect',
                            background: C.jade,
                            labelColor: C.bg,
                            weight: 600,
                            onTap: onReconnect,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Close and wipe',
                            background: C.dangerSurface,
                            labelColor: C.textSecondary,
                            weight: 500,
                            onTap: onCloseAndWipe,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: PageSkeleton(opacity: 0.34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two-button row's fills (`#7FC8A9` jade, `#241C1D` danger surface with
/// plain secondary text) match neither existing [PillTone] exactly, so this
/// is a small local button rather than a third bespoke tone added to a
/// shared primitive for one screen.
class _TunnelActionButton extends StatelessWidget {
  const _TunnelActionButton({
    required this.label,
    required this.background,
    required this.labelColor,
    required this.weight,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color labelColor;
  final int weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Text(label, style: ui(size: 13.5, weight: weight, color: labelColor)),
        ),
      ),
    );
  }
}
