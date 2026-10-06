import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void _role(TextStyle s, String family, double size, FontWeight weight, double line, Color color,
    {double letterSpacing = 0}) {
  expect(s.fontFamily, family);
  expect(s.fontSize, size);
  expect(s.fontWeight, weight);
  expect(s.height! * size, closeTo(line, 0.01));
  expect(s.color, color);
  expect(s.letterSpacing ?? 0, letterSpacing);
}

void main() {
  const sans = 'IBMPlexSans', monoF = 'IBMPlexMono';

  test('ui() is Plex Sans and maps weights to the three static faces', () {
    expect(ui(size: 16).fontFamily, sans);
    expect(ui(size: 16, weight: 700).fontWeight, FontWeight.w600);
    expect(ui(size: 16, weight: 500).fontWeight, FontWeight.w500);
    expect(ui(size: 16, weight: 300).fontWeight, FontWeight.w400);
    expect(ui(size: 16).fontVariations, isNull);
    expect(mono(size: 14).fontFamily, monoF);
  });

  test('the v2 scale (spec §3.2)', () {
    _role(T.display, monoF, 40, FontWeight.w500, 48, C.textPrimary, letterSpacing: -0.4);
    _role(T.stepTitle, sans, 26, FontWeight.w600, 32, C.textPrimary, letterSpacing: -0.26);
    _role(T.screenTitle, sans, 22, FontWeight.w600, 28, C.textPrimary);
    _role(T.sheetTitle, sans, 20, FontWeight.w600, 26, C.textPrimary);
    _role(T.appBarTitle, sans, 18, FontWeight.w600, 24, C.textPrimary);
    _role(T.keypad, monoF, 28, FontWeight.w400, 32, C.textPrimary);
    _role(T.rowTitle, sans, 16, FontWeight.w500, 22, C.textPrimary);
    _role(T.rowTitleIdle, sans, 16, FontWeight.w500, 22, C.textMuted);
    _role(T.body, sans, 16, FontWeight.w400, 24, C.textPrimary);
    _role(T.label, sans, 16, FontWeight.w600, 20, C.textPrimary);
    _role(T.address, sans, 16, FontWeight.w500, 20, C.textPrimary);
    _role(T.bodyMuted, sans, 15, FontWeight.w400, 22, C.textMuted);
    _role(T.sub, sans, 14, FontWeight.w400, 20, C.textMuted);
    _role(T.value, monoF, 14, FontWeight.w400, 20, C.textMuted);
    _role(T.sectionLabel, sans, 13, FontWeight.w600, 18, C.textMuted, letterSpacing: 0.52);
    _role(T.sectionLabelLive, sans, 13, FontWeight.w600, 18, C.jade, letterSpacing: 0.52);
    _role(T.meta, sans, 13, FontWeight.w400, 18, C.textFaint);
    _role(T.metaIdle, sans, 13, FontWeight.w400, 18, C.textFaint);
    _role(T.metaValue, monoF, 13, FontWeight.w400, 18, C.textFaint);
    _role(T.barSummary, sans, 13, FontWeight.w400, 18, C.textFaint);
    _role(T.barBadge, sans, 12, FontWeight.w600, 16, C.textMuted, letterSpacing: 0.24);
    _role(T.tab, sans, 13, FontWeight.w500, 16, C.textMuted);
    _role(T.tabSelected, sans, 13, FontWeight.w600, 16, C.textPrimary);
    _role(T.code, monoF, 13, FontWeight.w400, 22, C.code);
  });

  test('nothing in the scale is under 13 sp except the badge', () {
    final roles = [
      T.display, T.stepTitle, T.screenTitle, T.sheetTitle, T.appBarTitle, T.keypad,
      T.rowTitle, T.rowTitleIdle, T.body, T.label, T.address, T.bodyMuted, T.sub,
      T.value, T.sectionLabel, T.sectionLabelLive, T.meta, T.metaIdle, T.metaValue,
      T.barSummary, T.tab, T.tabSelected, T.code,
    ];
    for (final r in roles) {
      expect(r.fontSize, greaterThanOrEqualTo(13));
    }
    expect(T.barBadge.fontSize, 12);
  });
}
