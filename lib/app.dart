import 'package:flutter/material.dart';

import 'ui/core/palette_scope.dart';
import 'ui/core/theme.dart';
import 'ui/core/tokens.dart';

class ContainerApp extends StatelessWidget {
  const ContainerApp({super.key, this.home});

  /// Overridden by [main]; defaults to a bare surface so widget tests can
  /// pump the app without a database.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Container',
      debugShowCheckedModeBanner: false,
      // The app follows the phone's light/dark setting (spec §9); there is no
      // switch of its own.
      theme: containerTheme(Brightness.light),
      darkTheme: containerTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      // C switches at once; the Material theme must not lag behind it.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => PaletteScope(child: child ?? const SizedBox.shrink()),
      home: home ?? const _BareSurface(),
    );
  }
}

/// The default home: an empty page in the active palette. It reads [C] in its
/// own build, below `PaletteScope`, never in [ContainerApp]'s.
class _BareSurface extends StatelessWidget {
  const _BareSurface();

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: C.bg);
}
