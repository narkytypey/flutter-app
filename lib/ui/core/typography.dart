import 'package:flutter/widgets.dart';

import 'tokens.dart';

const _figtree = 'Figtree';
const _plexMono = 'IBMPlexMono';

/// Figtree is bundled as a variable font, so every style sets both
/// [TextStyle.fontWeight] and an explicit `wght` variation. Setting only one
/// of the two renders at the wrong weight on some engine versions.
TextStyle ui({
  required double size,
  int weight = 400,
  Color color = C.textPrimary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _figtree,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

TextStyle mono({
  required double size,
  int weight = 400,
  Color color = C.textSecondary,
  double? height,
}) {
  return TextStyle(
    fontFamily: _plexMono,
    fontSize: size,
    height: height,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  );
}

/// Named styles that recur across the screen set.
abstract final class T {
  static TextStyle get screenTitle => ui(size: 16, weight: 600);
  static TextStyle get sheetTitle => ui(size: 17, weight: 600, letterSpacing: -0.17);
  static TextStyle get stepTitle => ui(size: 22, weight: 600, letterSpacing: -0.22);
  static TextStyle get appBarTitle => ui(size: 15, weight: 600);

  static TextStyle get rowTitle => ui(size: 14.5, weight: 500);
  static TextStyle get rowTitleIdle => ui(size: 14.5, weight: 500, color: C.textTertiary);

  static TextStyle get body => ui(size: 14);
  static TextStyle get bodyMuted => ui(size: 13, color: C.textMuted, height: 1.65);

  static TextStyle get meta => ui(size: 10.5, color: C.textFaint);
  static TextStyle get metaIdle => ui(size: 10.5, color: C.textDim);

  /// 10px / 500 / .1em uppercase — the section label used across the set.
  static TextStyle get sectionLabel =>
      ui(size: 10, weight: 500, letterSpacing: 1.0, color: C.textFaint);
  static TextStyle get sectionLabelLive =>
      ui(size: 10, weight: 500, letterSpacing: 1.0, color: C.jade);

  /// The workspace summary on the right of the dashboard bar (spec `1b`).
  static TextStyle get barSummary => ui(size: 10, color: C.textFaint);

  /// The storage-rule badge that replaces it (spec `5b`).
  static TextStyle get barBadge =>
      ui(size: 10.5, weight: 500, letterSpacing: 0.63, color: C.textFaint);

  static TextStyle get code => mono(size: 11.5, height: 1.9, color: C.jadeCode);
}
