import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData containerTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'IBMPlexSans',
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
}
