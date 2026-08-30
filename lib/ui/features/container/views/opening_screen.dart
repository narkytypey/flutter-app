import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/open_step.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `8a` — shown while a container is coming up: the checklist of what is
/// being applied before the page appears, and nothing else loads meanwhile.
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line07)),
              ),
              child: Row(
                children: [
                  _IconButton(glyph: '‹', onTap: onCancel),
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: C.line08),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: C.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(host,
                              style: ui(size: 11.5, color: const Color(0xFFA9B0AE))),
                        ],
                      ),
                    ),
                  ),
                  _IconButton(glyph: '×', onTap: onCancel),
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
                    child: Container(color: C.jade),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
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
              padding: const EdgeInsets.fromLTRB(34, 0, 34, 30),
              child: Text(
                'Nothing loads until the tunnel is up.',
                style: ui(size: 12, height: 1.6, color: C.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.glyph, required this.onTap});

  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(child: Text(glyph, style: ui(size: 16, color: C.icon))),
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
        const SizedBox(width: 11),
        Text(step.label, style: ui(size: 13.5, color: _labelColor(step.state))),
      ],
    );
  }

  Color _labelColor(OpenStepState state) => switch (state) {
        OpenStepState.done => C.textMuted,
        OpenStepState.running => C.textSecondary,
        OpenStepState.pending => C.textDim,
      };
}

class _StepMarker extends StatelessWidget {
  const _StepMarker(this.state);

  final OpenStepState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      OpenStepState.done =>
        Text('✓', style: ui(size: 12, color: C.jade)),
      OpenStepState.running => const SizedBox(
          width: 11,
          height: 11,
          child: CustomPaint(painter: _RingGapPainter()),
        ),
      OpenStepState.pending => Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.5),
            border: const Border.fromBorderSide(
                BorderSide(color: C.textDim, width: 1.5)),
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
  const _RingGapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const gap = 0.5; // radians, centred on the top of the ring
    canvas.drawArc(rect.deflate(paint.strokeWidth / 2),
        -math.pi / 2 + gap / 2, math.pi * 2 - gap, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
