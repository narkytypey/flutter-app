import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData containerTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Figtree',
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: const ColorScheme.dark(
      surface: C.bg,
      onSurface: C.textPrimary,
      primary: C.jade,
      onPrimary: C.bg,
      secondary: C.jade,
      error: C.danger,
    ),
    dividerColor: C.line06,
    splashColor: C.line05,
    highlightColor: C.line05,
    textTheme: TextTheme(
      titleLarge: T.stepTitle,
      titleMedium: T.screenTitle,
      bodyLarge: T.rowTitle,
      bodyMedium: T.body,
      bodySmall: T.meta,
      labelSmall: T.sectionLabel,
    ),
  );
}
