import 'package:container/app.dart';
import 'package:container/ui/core/theme.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints [C.surface] as read in its own build. `const` everywhere it is
/// used, so only a forced rebuild can repaint it.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const Key('probe'), color: C.surface, child: const SizedBox(width: 10, height: 10));
}

/// A home with its own navigator, like the open vault's in `AppGate`.
class _NestedHome extends StatelessWidget {
  const _NestedHome();

  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: _Probe())),
              ),
              child: const Text('push'),
            ),
          ),
        ),
      );
}

Color _probeColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(const Key('probe'))).color;

void main() {
  testWidgets('a light phone gets the light page', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ContainerApp());

    expect(C.brightness, Brightness.light);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Palette.light.bg);
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness, Brightness.light);
  });

  testWidgets('switching to dark repaints a route pushed on a nested navigator',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ContainerApp(home: _NestedHome()));
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(_probeColor(tester), Palette.light.surface);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();

    expect(C.brightness, Brightness.dark);
    expect(_probeColor(tester), Palette.dark.surface);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(_probeColor(tester), Palette.light.surface);
  });

  testWidgets('the status bar icons follow the setting', (tester) async {
    SystemUiOverlayStyle style() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first)
        .value;

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ContainerApp());
    expect(style(), SystemUiOverlayStyle.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(style(), SystemUiOverlayStyle.light);
  });

  test('containerTheme builds each brightness from its palette', () {
    final light = containerTheme(Brightness.light);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.colorScheme.primary, Palette.light.jade);
    expect(light.colorScheme.onPrimary, Palette.light.onJade);
    expect(light.scaffoldBackgroundColor, Palette.light.bg);
    expect(light.textTheme.bodyMedium!.color, Palette.light.textPrimary);

    final dark = containerTheme(Brightness.dark);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, Palette.dark.jade);
    expect(dark.scaffoldBackgroundColor, Palette.dark.bg);
    expect(dark.textTheme.bodyMedium!.color, Palette.dark.textPrimary);

    // Building a theme leaves the active palette as it was.
    expect(C.brightness, Brightness.dark);
  });
}
