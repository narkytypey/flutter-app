import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Spec §6.6's set, drawn in-repo: no icon font, no dependency. The last
/// eight are the restyle's (`2026-10-02-restyle-design.md` §2),
/// and the dashboard redesign added the last three.
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
  check,
  plus,
  more,
  vault,
  fingerprint,
  backspace,
  refused,
  contrast,
  sites,
  today,
  settings,
  // Restyle v2 (spec §6).
  shieldHalf,
  shieldFull,
  sitesFilled,
  todayFilled,
  settingsFilled,
  caseSolid,
  caseBroken,
  caseDouble,
}

/// One line icon at the size the caller passes. Every icon in the app is one
/// of these: the restyle spec's §6 test fails on a Unicode glyph or a
/// Material `Icons.*`. Place it under loose constraints — under tight ones a
/// `CustomPaint` fills its box and the glyph scales with it.
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
        canvas.drawPath(_shield, stroke);
      case AppGlyph.shieldHalf:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(12, 21)
            ..cubicTo(8, 19.5, 5, 16.5, 5, 12)
            ..lineTo(5, 6)
            ..close(),
          Paint()..color = color,
        );
        canvas.drawPath(_shield, stroke);
      case AppGlyph.shieldFull:
        canvas.drawPath(_shield, Paint()..color = color);
        canvas.drawPath(_shield, stroke);
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
      case AppGlyph.check:
        _lines(canvas, stroke, const [Offset(5, 12.5), Offset(10, 17.5), Offset(19, 7.5)]);
      case AppGlyph.plus:
        _lines(canvas, stroke, const [Offset(12, 5), Offset(12, 19)]);
        _lines(canvas, stroke, const [Offset(5, 12), Offset(19, 12)]);
      case AppGlyph.more:
        final dot = Paint()..color = color;
        for (final x in const [5.5, 12.0, 18.5]) {
          canvas.drawCircle(Offset(x, 12), 1.75, dot);
        }
      case AppGlyph.vault:
        // The mark (restyle v2 §6): a closed case, its lid seam, one jewel.
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTRB(3, 3, 21, 21), const Radius.circular(6)),
            stroke);
        _lines(canvas, stroke, const [Offset(3, 9), Offset(21, 9)]);
        canvas.drawCircle(const Offset(12, 15), 3, Paint()..color = color);
      case AppGlyph.fingerprint:
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 13), radius: 8.5),
            _radians(200), _radians(140), false, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 16)
            ..lineTo(6.5, 13)
            ..arcToPoint(const Offset(17.5, 13), radius: const Radius.circular(5.5))
            ..lineTo(17.5, 17),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 18)
            ..lineTo(9.5, 13)
            ..arcToPoint(const Offset(14.5, 13), radius: const Radius.circular(2.5))
            ..lineTo(14.5, 20),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(12, 13), Offset(12, 16.5)]);
      case AppGlyph.backspace:
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 5.5)
            ..lineTo(20, 5.5)
            ..lineTo(20, 18.5)
            ..lineTo(8.5, 18.5)
            ..lineTo(3.5, 12)
            ..close(),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(11.5, 9.5), Offset(16.5, 14.5)]);
        _lines(canvas, stroke, const [Offset(16.5, 9.5), Offset(11.5, 14.5)]);
      case AppGlyph.refused:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        _lines(canvas, stroke, const [Offset(6, 18), Offset(18, 6)]);
      case AppGlyph.contrast:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..arcToPoint(const Offset(12, 20), radius: const Radius.circular(8))
            ..close(),
          Paint()..color = color,
        );
      case AppGlyph.sites:
        for (final corner in const [Offset(4, 4), Offset(14, 4), Offset(4, 14), Offset(14, 14)]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(corner & const Size(6, 6), const Radius.circular(1.5)),
            stroke,
          );
        }
      case AppGlyph.sitesFilled:
        final fill = Paint()..color = color;
        for (final corner in const [Offset(4, 4), Offset(14, 4), Offset(4, 14), Offset(14, 14)]) {
          final r = RRect.fromRectAndRadius(corner & const Size(6, 6), const Radius.circular(1.5));
          canvas.drawRRect(r, fill);
          canvas.drawRRect(r, stroke);
        }
      case AppGlyph.today:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(4, 6, 20, 20), const Radius.circular(2)),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(4, 10.5), Offset(20, 10.5)]);
        _lines(canvas, stroke, const [Offset(8.5, 3.5), Offset(8.5, 7.5)]);
        _lines(canvas, stroke, const [Offset(15.5, 3.5), Offset(15.5, 7.5)]);
      case AppGlyph.todayFilled:
        final body =
            RRect.fromRectAndRadius(const Rect.fromLTRB(4, 6, 20, 20), const Radius.circular(2));
        canvas.drawRRect(body, Paint()..color = color);
        canvas.drawRRect(body, stroke);
        _lines(canvas, stroke, const [Offset(8.5, 3.5), Offset(8.5, 7.5)]);
        _lines(canvas, stroke, const [Offset(15.5, 3.5), Offset(15.5, 7.5)]);
      case AppGlyph.settingsFilled:
        final knobFill = Paint()..color = color;
        for (final (y, knob) in const [(7.0, 15.0), (12.0, 9.0), (17.0, 13.0)]) {
          _lines(canvas, stroke, [Offset(4, y), Offset(20, y)]);
          canvas.drawCircle(Offset(knob, y), 2.6, knobFill);
        }
      case AppGlyph.caseSolid:
        canvas.drawRRect(_case, stroke);
        _lines(canvas, stroke, const [Offset(4, 9.5), Offset(20, 9.5)]);
      case AppGlyph.caseBroken:
        _dashed(canvas, stroke, Path()..addRRect(_case), on: 3, off: 2);
        _lines(canvas, stroke, const [Offset(4, 9.5), Offset(20, 9.5)]);
      case AppGlyph.caseDouble:
        canvas.drawRRect(_case, stroke);
        _lines(canvas, stroke, const [Offset(4, 9.5), Offset(20, 9.5)]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(1.5, 1.5, 22.5, 22.5), const Radius.circular(7)),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case AppGlyph.settings:
        // Three sliders: each line stops at its knob, a ring.
        for (final (y, knob) in const [(7.0, 15.0), (12.0, 9.0), (17.0, 13.0)]) {
          _lines(canvas, stroke, [Offset(4, y), Offset(knob - 2, y)]);
          canvas.drawCircle(Offset(knob, y), 2, stroke);
          _lines(canvas, stroke, [Offset(knob + 2, y), Offset(20, y)]);
        }
    }
    canvas.restore();
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static final _shield = Path()
    ..moveTo(12, 3)
    ..lineTo(19, 6)
    ..lineTo(19, 12)
    ..cubicTo(19, 16.5, 16, 19.5, 12, 21)
    ..cubicTo(8, 19.5, 5, 16.5, 5, 12)
    ..lineTo(5, 6)
    ..close();

  static final _case =
      RRect.fromRectAndRadius(const Rect.fromLTRB(4, 4, 20, 20), const Radius.circular(5));

  /// Strokes [path] as dashes of [on] units with [off]-unit gaps.
  static void _dashed(Canvas canvas, Paint paint, Path path,
      {required double on, required double off}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + on, metric.length)), paint);
        d += on + off;
      }
    }
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
