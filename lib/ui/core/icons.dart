import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Spec §6.6's set, drawn in-repo: no icon font, no dependency.
enum AppGlyph {
  back,
  forward,
  reload,
  stop,
  shield,
  panic,
  menu,
  find,
  reader,
  link,
  search,
  globe,
  chevronUp,
  chevronDown,
  close,
}

/// One line icon at the size the caller passes. Replaces `2b`'s Unicode
/// glyphs on the container screen; other screens keep theirs until project 4.
class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 20, this.color = C.icon});

  final AppGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: AppIconPainter(glyph, color));
}

/// Draws [glyph] with 2-unit round strokes on a 24-unit grid, scaled to the
/// canvas. The paths follow the brainstorm mockups
/// (`.superpowers/brainstorm/…/typing-and-menu.html`).
class AppIconPainter extends CustomPainter {
  const AppIconPainter(this.glyph, this.color);

  final AppGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case AppGlyph.back:
        _lines(canvas, stroke, const [Offset(15, 18), Offset(9, 12), Offset(15, 6)]);
      case AppGlyph.forward:
        _lines(canvas, stroke, const [Offset(9, 18), Offset(15, 12), Offset(9, 6)]);
      case AppGlyph.chevronUp:
        _lines(canvas, stroke, const [Offset(6, 15), Offset(12, 9), Offset(18, 15)]);
      case AppGlyph.chevronDown:
        _lines(canvas, stroke, const [Offset(6, 9), Offset(12, 15), Offset(18, 9)]);
      case AppGlyph.close:
        _lines(canvas, stroke, const [Offset(6, 6), Offset(18, 18)]);
        _lines(canvas, stroke, const [Offset(18, 6), Offset(6, 18)]);
      case AppGlyph.stop:
        _lines(canvas, stroke, const [Offset(7, 7), Offset(17, 17)]);
        _lines(canvas, stroke, const [Offset(17, 7), Offset(7, 17)]);
      case AppGlyph.reload:
        canvas.drawPath(
          Path()
            ..moveTo(20, 12)
            ..arcToPoint(const Offset(17.6, 6.3),
                radius: const Radius.circular(8), largeArc: true)
            ..lineTo(20, 8.5),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(20, 3.5), Offset(20, 8.5), Offset(15, 8.5)]);
      case AppGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(19, 6)
            ..lineTo(19, 12)
            ..cubicTo(19, 16.5, 16, 19.5, 12, 21)
            ..cubicTo(8, 19.5, 5, 16.5, 5, 12)
            ..lineTo(5, 6)
            ..close(),
          stroke,
        );
      case AppGlyph.panic:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawCircle(const Offset(12, 12), 3.2, Paint()..color = color);
      case AppGlyph.menu:
        _lines(canvas, stroke, const [Offset(4, 7), Offset(20, 7)]);
        _lines(canvas, stroke, const [Offset(4, 12), Offset(20, 12)]);
        _lines(canvas, stroke, const [Offset(4, 17), Offset(20, 17)]);
      case AppGlyph.find:
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        _lines(canvas, stroke, const [Offset(20, 20), Offset(15.8, 15.8)]);
        _lines(canvas, stroke, const [Offset(8.5, 11), Offset(13.5, 11)]);
      case AppGlyph.search:
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        _lines(canvas, stroke, const [Offset(20, 20), Offset(15.8, 15.8)]);
      case AppGlyph.reader:
        _lines(canvas, stroke, const [Offset(5, 5), Offset(19, 5)]);
        _lines(canvas, stroke, const [Offset(5, 10), Offset(19, 10)]);
        _lines(canvas, stroke, const [Offset(5, 15), Offset(14, 15)]);
        _lines(canvas, stroke, const [Offset(5, 20), Offset(11, 20)]);
      case AppGlyph.link:
        canvas.drawPath(
          Path()
            ..moveTo(10, 14)
            ..arcToPoint(const Offset(15.7, 14),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(18.7, 11)
            ..arcToPoint(const Offset(13, 5.3),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(12, 6.3),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14, 10)
            ..arcToPoint(const Offset(8.3, 10),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(5.3, 13)
            ..arcToPoint(const Offset(11, 18.7),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(12, 17.7),
          stroke,
        );
      case AppGlyph.globe:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        _lines(canvas, stroke, const [Offset(3.5, 12), Offset(20.5, 12)]);
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..cubicTo(14.5, 6.1, 15.5, 8.9, 15.5, 12)
            ..cubicTo(15.5, 15.1, 14.5, 17.9, 12, 20.5)
            ..cubicTo(9.5, 17.9, 8.5, 15.1, 8.5, 12)
            ..cubicTo(8.5, 8.9, 9.5, 6.1, 12, 3.5)
            ..close(),
          stroke,
        );
    }
    canvas.restore();
  }

  static void _lines(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
