import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A dashed rounded square. Flutter has no dashed border, so the empty state's
/// placeholder is painted.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.size,
    required this.radius,
    this.color = C.line16,
  });

  final double size;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _DashedPainter(radius: radius, color: color),
      );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.radius != radius || old.color != color;
}
