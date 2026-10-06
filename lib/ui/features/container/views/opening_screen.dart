import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/open_step.dart';
import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

/// Spec `8a` — shown while a container is coming up: the checklist of what is
/// being applied before the page appears, and nothing else loads meanwhile.
///
/// Restyle v2 §8 `8a`: the current step in text-1, pending ones in text-3,
/// done ones in text-2 behind a text-2 check; no jade anywhere (nothing is
/// live yet: the pill's light is amber); the progress line is text-2; every
/// line wraps, the host after its dots, and nothing is cut short.
class OpeningBody extends StatelessWidget {
  const OpeningBody({
    super.key,
    required this.host,
    required this.steps,
    required this.progress,
    required this.onCancel,
  });

  final String host;
  final List<OpenStep> steps;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  IconTap(
                    glyph: AppGlyph.back,
                    label: 'Back',
                    onTap: onCancel,
                    iconSize: 22,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: C.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: C.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HostText(host, style: T.address.copyWith(color: C.pillText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconTap(
                    glyph: AppGlyph.close,
                    label: 'Close',
                    onTap: onCancel,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: Stack(
                children: [
                  Container(color: C.barTrack),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: C.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Starting a clean container', style: T.screenTitle),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < steps.length; i++) ...[
                            if (i != 0) const SizedBox(height: 14),
                            _StepRow(steps[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Text(
                'Nothing loads until the tunnel is up.',
                style: T.sub.copyWith(color: C.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final OpenStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepMarker(step.state),
        const SizedBox(width: 12),
        Flexible(
          child: Text(step.label, style: T.bodyMuted.copyWith(color: _labelColor(step.state))),
        ),
      ],
    );
  }

  Color _labelColor(OpenStepState state) => switch (state) {
        OpenStepState.done => C.textMuted,
        OpenStepState.running => C.textPrimary,
        OpenStepState.pending => C.textFaint,
      };
}

class _StepMarker extends StatelessWidget {
  const _StepMarker(this.state);

  final OpenStepState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      OpenStepState.done => AppIcon(AppGlyph.check, size: 14, color: C.textMuted),
      OpenStepState.running => SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: _RingGapPainter()),
        ),
      OpenStepState.pending => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.fromBorderSide(BorderSide(color: C.edge, width: 2)),
          ),
        ),
    };
  }
}

/// A ring with a 90° gap centred on top — the "connecting" spinner shape:
/// CSS's `border-top-color: transparent` on a circular border, redrawn with
/// [Canvas.drawArc] because [BoxDecoration] refuses a non-uniform border
/// colour on a rounded shape.
class _RingGapPainter extends CustomPainter {
  _RingGapPainter() : color = C.warning;

  /// The active palette's warning, so a light/dark switch repaints it.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const gap = 0.5; // radians, centred on the top of the ring
    canvas.drawArc(rect.deflate(paint.strokeWidth / 2),
        -math.pi / 2 + gap / 2, math.pi * 2 - gap, false, paint);
  }

  @override
  bool shouldRepaint(_RingGapPainter oldDelegate) => oldDelegate.color != color;
}
