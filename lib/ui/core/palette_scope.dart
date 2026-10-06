import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Follows the phone's light/dark setting (restyle v2 spec §9).
///
/// It reads the system brightness, makes that palette [C]'s active one, and
/// sets the status bar's icons to match: dark icons on light, light on dark.
/// [C] is read without a `BuildContext` all over the app, by painters, default
/// parameters and `T.*`, so no `InheritedWidget` could tell those places the
/// palette changed. Instead, when the brightness changes, every element below
/// this one is marked for rebuild, which reaches the open vault's own
/// navigator and every route and sheet on it. It sits in
/// `MaterialApp.builder`, so the app's navigator is below it. Nothing here
/// depends on which vault is open.
class PaletteScope extends StatefulWidget {
  const PaletteScope({super.key, required this.child});

  final Widget child;

  @override
  State<PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<PaletteScope> {
  Brightness? _applied;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _applied) {
      final changed = _applied != null;
      _applied = brightness;
      C.use(brightness);
      // The first build has nothing built yet with the old palette.
      if (changed) _rebuildDescendants(context as Element);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: widget.child,
    );
  }

  /// Marks every element below [element] dirty, so each one builds again
  /// with the new palette in this same frame.
  static void _rebuildDescendants(Element element) {
    void visit(Element child) {
      child.markNeedsBuild();
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
  }
}
