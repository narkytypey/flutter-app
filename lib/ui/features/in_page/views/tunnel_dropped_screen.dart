import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/page_skeleton.dart';
import 'proxy_unreachable_screen.dart' show TunnelHeader;

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
            TunnelHeader(host: host, rule: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(S.s3, S.s1, S.s3, 0),
              child: Container(
                padding: const EdgeInsets.all(S.s4),
                decoration: BoxDecoration(
                  color: C.dangerSurface,
                  borderRadius: BorderRadius.circular(R.group),
                  border: Border.all(color: C.danger.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppIcon(AppGlyph.refused, size: 16, color: C.danger),
                        const SizedBox(width: S.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tunnel dropped', style: T.label),
                              const SizedBox(height: S.s1),
                              Text(
                                'The page is paused. Nothing further has been requested '
                                'since the connection failed $droppedAgoLabel.',
                                style: T.sub,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: S.s4),
                    Row(
                      children: [
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Reconnect',
                            background: C.jade,
                            labelColor: C.onJade,
                            weight: 600,
                            onTap: onReconnect,
                          ),
                        ),
                        const SizedBox(width: S.s2),
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Close and wipe',
                            background: C.button,
                            labelColor: C.textPrimary,
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

/// The banner's two buttons, side by side: jade `Reconnect` (the one
/// affirmative action, restyle v2 §8) and a neutral `Close and wipe`. A
/// small local button keeps them in the banner's row at their own width.
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
      borderRadius: BorderRadius.circular(R.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.full),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: S.s2, vertical: S.s1),
          alignment: Alignment.center,
          child: Text(label,
              textAlign: TextAlign.center,
              style: T.label.copyWith(
                  color: labelColor,
                  fontWeight: weight >= 600 ? FontWeight.w600 : FontWeight.w500)),
        ),
      ),
    );
  }
}
