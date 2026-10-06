import 'dart:math' as math;
import 'dart:ui';

import 'package:container/ui/core/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG 2.1 contrast ratio.
double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('surfaces are the four v2 tones', () {
    expect(C.bg, const Color(0xFF121110));
    expect(C.surface, const Color(0xFF22201D));
    expect(C.sheet, const Color(0xFF302D29));
    expect(C.button, const Color(0xFF403C37));
    expect(C.selected, const Color(0xFF403C37));
  });

  test('text tones and state colours', () {
    expect(C.textPrimary, const Color(0xFFEDEAE4));
    expect(C.textMuted, const Color(0xFFCBC4B9));
    expect(C.textFaint, const Color(0xFFA8A095));
    expect(C.jade, const Color(0xFF7FC8A9));
    expect(C.danger, const Color(0xFFEE8D79));
    expect(C.warning, const Color(0xFFE0B266));
    expect(C.edge, const Color(0xFF958D82));
    expect(C.code, const Color(0xFFD9CFB8));
    expect(C.lineSoft, const Color(0x14EDEAE4));
    expect(C.line, const Color(0x24EDEAE4));
  });

  test('every text tone is at least 4.5:1 on every surface it may sit on', () {
    for (final s in [C.bg, C.surface, C.sheet]) {
      for (final t in [
        C.textPrimary,
        C.textMuted,
        C.textFaint,
        C.jade,
        C.danger,
        C.warning,
        C.code,
      ]) {
        expect(contrast(t, s), greaterThanOrEqualTo(4.5), reason: '$t on $s');
      }
    }
    for (final t in [C.textPrimary, C.textMuted, C.danger]) {
      expect(contrast(t, C.button), greaterThanOrEqualTo(4.5),
          reason: '$t on button');
    }
    expect(contrast(C.textPrimary, C.dangerSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(C.danger, C.dangerSurface), greaterThanOrEqualTo(4.5));
    expect(contrast(C.onJade, C.jade), greaterThanOrEqualTo(4.5));
    for (final t in [C.readerTitle, C.readerBody, C.readerMuted]) {
      expect(contrast(t, C.bgReader), greaterThanOrEqualTo(4.5));
    }
  });

  test('every meaningful mark is at least 3:1', () {
    for (final s in [C.bg, C.surface, C.sheet, C.button]) {
      expect(contrast(C.edge, s), greaterThanOrEqualTo(3.0), reason: 'edge on $s');
    }
    for (final m in C.markers) {
      expect(contrast(m, C.bg), greaterThanOrEqualTo(3.0));
    }
  });

  test('surfaces step at least 1.15:1', () {
    expect(contrast(C.surface, C.bg), greaterThanOrEqualTo(1.15));
    expect(contrast(C.sheet, C.surface), greaterThanOrEqualTo(1.15));
    expect(contrast(C.button, C.sheet), greaterThanOrEqualTo(1.15));
  });

  test('no workspace marker is jade', () {
    expect(C.markers, isNot(contains(C.jade)));
    expect(C.markers, hasLength(5));
  });
}
