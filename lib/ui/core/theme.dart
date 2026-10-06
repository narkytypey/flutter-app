import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// The Material theme for [brightness], built from that brightness's
/// [Palette] (spec §9). `MaterialApp` builds both before `PaletteScope` has
/// chosen the active palette, so this switches [C] to [brightness] while it
/// reads it and puts the previous palette back.
ThemeData containerTheme([Brightness brightness = Brightness.dark]) {
  final previous = C.brightness;
  C.use(brightness);
  try {
    final colorScheme = brightness == Brightness.light
        ? ColorScheme.light(
            surface: C.bg,
            onSurface: C.textPrimary,
            primary: C.jade,
            onPrimary: C.onJade,
            secondary: C.jade,
            error: C.danger,
          )
        : ColorScheme.dark(
            surface: C.bg,
            onSurface: C.textPrimary,
            primary: C.jade,
            onPrimary: C.onJade,
            secondary: C.jade,
            error: C.danger,
          );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'IBMPlexSans',
      scaffoldBackgroundColor: C.bg,
      canvasColor: C.bg,
      colorScheme: colorScheme,
      dividerColor: C.lineSoft,
      splashColor: C.lineSoft,
      highlightColor: C.lineSoft,
      textTheme: TextTheme(
        titleLarge: T.stepTitle,
        titleMedium: T.screenTitle,
        bodyLarge: T.rowTitle,
        bodyMedium: T.body,
        bodySmall: T.meta,
        labelSmall: T.sectionLabel,
      ),
    );
  } finally {
    C.use(previous);
  }
}
