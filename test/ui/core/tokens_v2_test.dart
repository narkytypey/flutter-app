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
  test('surfaces are the four cyberpunk tones', () {
    expect(C.bg, const Color(0xFF0B0D12));
    expect(C.surface, const Color(0xFF1A1F2A));
    expect(C.sheet, const Color(0xFF252B39));
    expect(C.button, const Color(0xFF31394A));
    expect(C.selected, const Color(0xFF31394A));
  });

  test('text tones and state colours', () {
    expect(C.textPrimary, const Color(0xFFE6EDF7));
    expect(C.textMuted, const Color(0xFFB8C3D6));
    expect(C.textFaint, const Color(0xFF97A3BA));
    expect(C.jade, const Color(0xFF3DF5D0));
    expect(C.danger, const Color(0xFFFF7AA6));
    expect(C.warning, const Color(0xFFF5D13D));
    expect(C.edge, const Color(0xFF7A87A0));
    expect(C.code, const Color(0xFFC9B8FF));
    expect(C.lineSoft, const Color(0x14E6EDF7));
    expect(C.line, const Color(0x24E6EDF7));
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

  group('light palette (Plan 24, spec §9)', () {
    tearDown(() => C.use(Brightness.dark));

    test('Palette.dark holds exactly the cyberpunk dark values', () {
      const d = Palette.dark;
      expect(d.bg, const Color(0xFF0B0D12));
      // Reader keeps v2's warm values (cyberpunk spec §2.5).
      expect(d.bgReader, const Color(0xFF15120E));
      expect(d.surface, const Color(0xFF1A1F2A));
      expect(d.skeleton, const Color(0xFF1A1F2A));
      expect(d.barTrack, const Color(0xFF1A1F2A));
      expect(d.sheet, const Color(0xFF252B39));
      for (final c in [d.button, d.selected, d.monogramOpen]) {
        expect(c, const Color(0xFF31394A));
      }
      for (final c in [d.textPrimary, d.textSecondary, d.monogramText, d.pillText, d.focus]) {
        expect(c, const Color(0xFFE6EDF7));
      }
      for (final c in [d.textTertiary, d.textMuted, d.icon, d.tabInactive]) {
        expect(c, const Color(0xFFB8C3D6));
      }
      for (final c in [d.textFaint, d.chevron, d.knobOff]) {
        expect(c, const Color(0xFF97A3BA));
      }
      for (final c in [d.edge, d.handle, d.idleDot, d.pinEmpty]) {
        expect(c, const Color(0xFF7A87A0));
      }
      expect(d.line, const Color(0x24E6EDF7));
      expect(d.lineSoft, const Color(0x14E6EDF7));
      expect(d.jade, const Color(0xFF3DF5D0));
      expect(d.onJade, const Color(0xFF0B0D12));
      expect(d.code, const Color(0xFFC9B8FF));
      expect(d.danger, const Color(0xFFFF7AA6));
      expect(d.pinError, const Color(0xFFFF7AA6));
      expect(d.dangerSurface, const Color(0xFF2A1520));
      expect(d.warning, const Color(0xFFF5D13D));
      expect(d.readerMuted, const Color(0xFFA39A8C));
      expect(d.readerTitle, const Color(0xFFEFE8DC));
      expect(d.readerBody, const Color(0xFFD3CBBE));
      expect(d.markers, const [
        Color(0xFFFF8FCF),
        Color(0xFF8FB0FF),
        Color(0xFFF5D13D),
        Color(0xFFC49BFF),
        Color(0xFF97A3BA),
      ]);
    });

    test('Palette.light holds spec §9 values', () {
      const l = Palette.light;
      expect(l.bg, const Color(0xFFF3F0EA));
      expect(l.bgReader, const Color(0xFFF6F1E7));
      expect(l.surface, const Color(0xFFFFFFFF));
      expect(l.skeleton, const Color(0xFFE9E4DC));
      expect(l.barTrack, const Color(0xFFE9E4DC));
      expect(l.sheet, const Color(0xFFFAF8F4));
      for (final c in [l.button, l.selected, l.monogramOpen]) {
        expect(c, const Color(0xFFE3DDD3));
      }
      for (final c in [l.textPrimary, l.textSecondary, l.monogramText, l.pillText, l.focus]) {
        expect(c, const Color(0xFF1C1A17));
      }
      for (final c in [l.textTertiary, l.textMuted, l.icon, l.tabInactive]) {
        expect(c, const Color(0xFF4B453D));
      }
      for (final c in [l.textFaint, l.chevron, l.knobOff]) {
        expect(c, const Color(0xFF686157));
      }
      for (final c in [l.edge, l.handle, l.idleDot, l.pinEmpty]) {
        expect(c, const Color(0xFF857D72));
      }
      expect(l.line, const Color(0x241C1A17));
      expect(l.lineSoft, const Color(0x141C1A17));
      expect(l.jade, const Color(0xFF1D6B57));
      expect(l.onJade, const Color(0xFFFFFFFF));
      expect(l.code, const Color(0xFF7A5718));
      expect(l.danger, const Color(0xFFB3261E));
      expect(l.pinError, const Color(0xFFB3261E));
      expect(l.dangerSurface, const Color(0xFFFBEAE6));
      expect(l.warning, const Color(0xFF8A5800));
      expect(l.readerMuted, const Color(0xFF5E564B));
      expect(l.readerTitle, const Color(0xFF2B2620));
      expect(l.readerBody, const Color(0xFF3A342C));
      expect(l.markers, const [
        Color(0xFF7D6532),
        Color(0xFF3D5F8F),
        Color(0xFF8A5800),
        Color(0xFF8A4F72),
        Color(0xFF6E675D),
      ]);
    });

    test('C.use switches the active palette', () {
      C.use(Brightness.light);
      expect(C.brightness, Brightness.light);
      expect(C.bg, const Color(0xFFF3F0EA));
      expect(C.markers, Palette.light.markers);
      C.use(Brightness.dark);
      expect(C.brightness, Brightness.dark);
      expect(C.bg, const Color(0xFF0B0D12));
      expect(C.markers, Palette.dark.markers);
    });

    test('every light pairing reaches its stated contrast', () {
      const l = Palette.light;
      final surfaces = [l.bg, l.surface, l.sheet, l.button];
      // Text-1, text-2 and text-3 on all four surfaces (text-3 on raised is
      // 4.53:1), and jade, code and danger text likewise.
      for (final s in surfaces) {
        for (final t in [l.textPrimary, l.textMuted, l.textFaint, l.jade, l.code, l.danger]) {
          expect(contrast(t, s), greaterThanOrEqualTo(4.5), reason: '$t on $s');
        }
        expect(contrast(l.edge, s), greaterThanOrEqualTo(3.0), reason: 'edge on $s');
      }
      // Warning and the markers on page, group and sheet (never on raised).
      for (final s in [l.bg, l.surface, l.sheet]) {
        expect(contrast(l.warning, s), greaterThanOrEqualTo(4.5), reason: 'warning on $s');
        for (final m in l.markers) {
          expect(contrast(m, s), greaterThanOrEqualTo(4.5), reason: '$m on $s');
        }
      }
      expect(contrast(l.onJade, l.jade), greaterThanOrEqualTo(4.5));
      expect(contrast(l.danger, l.dangerSurface), greaterThanOrEqualTo(4.5));
      expect(contrast(l.textPrimary, l.dangerSurface), greaterThanOrEqualTo(4.5));
      for (final t in [l.readerTitle, l.readerBody, l.readerMuted]) {
        expect(contrast(t, l.bgReader), greaterThanOrEqualTo(4.5));
      }
      expect(l.markers, isNot(contains(l.jade)));
    });
  });
}
