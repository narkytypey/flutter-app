import 'package:flutter/widgets.dart';

import 'tokens.dart';

const _sans = 'IBMPlexSans';
const _plexMono = 'IBMPlexMono';

/// IBM Plex Sans is bundled as three static faces (400, 500, 600), so a
/// weight maps to the nearest one: 600 and above is SemiBold, 400 and below
/// Regular. Restyle v2 spec §3.1.
FontWeight _sansWeight(int weight) => weight >= 600
    ? FontWeight.w600
    : weight >= 500
        ? FontWeight.w500
        : FontWeight.w400;

/// Every word of UI (spec §3.1).
TextStyle ui({
  required double size,
  int weight = 400,
  Color color = C.textPrimary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _sans,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: _sansWeight(weight),
  );
}

/// Values you could copy: hosts in rows, addresses, ports, counts, PIN
/// digits, code (spec §1.5). Plex Mono is bundled at 400 and 500.
TextStyle mono({
  required double size,
  int weight = 400,
  Color color = C.textSecondary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _plexMono,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: weight >= 500 ? FontWeight.w500 : FontWeight.w400,
  );
}

/// Named styles — restyle v2 spec §3.2. Line heights are the spec's sp
/// values, given to Flutter as a multiple of the size.
abstract final class T {
  /// The Today total (`5c`).
  static TextStyle get display =>
      mono(size: 40, weight: 500, height: 48 / 40, letterSpacing: -0.4, color: C.textPrimary);

  static TextStyle get stepTitle =>
      ui(size: 26, weight: 600, height: 32 / 26, letterSpacing: -0.26);
  static TextStyle get screenTitle => ui(size: 22, weight: 600, height: 28 / 22);
  static TextStyle get sheetTitle => ui(size: 20, weight: 600, height: 26 / 20);

  /// Centred form titles (`2a`, `10b`, `10e`).
  static TextStyle get appBarTitle => ui(size: 18, weight: 600, height: 24 / 18);

  /// A PIN keypad digit.
  static TextStyle get keypad => mono(size: 28, height: 32 / 28, color: C.textPrimary);

  static TextStyle get rowTitle => ui(size: 16, weight: 500, height: 22 / 16);

  /// Idle is said by the missing light, not by fading the name far.
  static TextStyle get rowTitleIdle =>
      ui(size: 16, weight: 500, height: 22 / 16, color: C.textTertiary);

  static TextStyle get body => ui(size: 16, height: 24 / 16);

  /// A button's label. Primary (jade) buttons pass `color: C.onJade`.
  static TextStyle get label => ui(size: 16, weight: 600, height: 20 / 16);

  /// The host in the address pill: the UI face, not Mono (spec §1.5).
  static TextStyle get address => ui(size: 16, weight: 500, height: 20 / 16);

  static TextStyle get bodyMuted => ui(size: 15, height: 22 / 15, color: C.textMuted);

  /// A row's subtitle.
  static TextStyle get sub => ui(size: 14, height: 20 / 14, color: C.textMuted);

  /// A value in a row (a proxy address, a count).
  static TextStyle get value => mono(size: 14, height: 20 / 14, color: C.textMuted);

  static TextStyle get meta => ui(size: 13, height: 18 / 13, color: C.textFaint);
  static TextStyle get metaIdle => ui(size: 13, height: 18 / 13, color: C.textFaint);

  /// A host inside a meta line.
  static TextStyle get metaValue => mono(size: 13, height: 18 / 13, color: C.textFaint);

  /// Section labels keep their stored case (spec §3.2): 13 / 600 / +0.52.
  static TextStyle get sectionLabel =>
      ui(size: 13, weight: 600, height: 18 / 13, letterSpacing: 0.52, color: C.textMuted);
  static TextStyle get sectionLabelLive =>
      ui(size: 13, weight: 600, height: 18 / 13, letterSpacing: 0.52, color: C.jade);

  /// The summary beside a bar (spec `1b`).
  static TextStyle get barSummary => ui(size: 13, height: 18 / 13, color: C.textFaint);

  /// Route and format badges (`SOCKS5`, `PDF`, `WIPES ON EXIT`): the one
  /// place under 13 sp, always beside another cue.
  static TextStyle get barBadge =>
      ui(size: 12, weight: 600, height: 16 / 12, letterSpacing: 0.24, color: C.textMuted);

  /// The dashboard's tab labels; the selected tab passes `weight: 600`
  /// through [tabSelected].
  static TextStyle get tab => ui(size: 13, weight: 500, height: 16 / 13, color: C.textMuted);
  static TextStyle get tabSelected =>
      ui(size: 13, weight: 600, height: 16 / 13, color: C.textPrimary);

  static TextStyle get code => mono(size: 13, height: 22 / 13, color: C.code);
}
