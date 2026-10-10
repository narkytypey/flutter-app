import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

// Restyle v2 §7: a protective change applying redraws the pill's case over
// 320 ms and moves the light amber → jade over 150 ms; with the system's
// animations off, both are 100 ms.
Future<void> _pump(
  WidgetTester tester, {
  CaseKind caseKind = CaseKind.keep,
  bool live = true,
  bool still = false,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(
            body: ContainerTopBar(
              host: 'forum.example.com',
              routeLabel: '',
              live: live,
              loading: false,
              onEditAddress: () {},
              onStop: () {},
              onReload: () {},
              onSiteDetails: () {},
              openCount: 1,
              onOpenSwitcher: () {},
              onMenu: () {},
              caseKind: caseKind,
            ),
          ),
        ),
      ),
    ));

Color _lightColour(WidgetTester tester) {
  final light = tester.widgetList<Container>(find.byType(Container)).firstWhere((c) =>
      c.decoration is BoxDecoration &&
      (c.decoration! as BoxDecoration).shape == BoxShape.circle);
  return (light.decoration! as BoxDecoration).color!;
}

void main() {
  test('the durations are the spec\'s', () {
    expect(ContainerTopBar.caseDuration, const Duration(milliseconds: 320));
    expect(ContainerTopBar.lightDuration, const Duration(milliseconds: 150));
    expect(ContainerTopBar.stillDuration, const Duration(milliseconds: 100));
  });

  testWidgets('the case cross-fades solid to broken over 320 ms', (tester) async {
    await _pump(tester);
    await _pump(tester, caseKind: CaseKind.wipe);
    await tester.pump(const Duration(milliseconds: 160));
    expect(findGlyph(AppGlyph.caseSolid), findsOneWidget);
    expect(findGlyph(AppGlyph.caseBroken), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 161));
    expect(findGlyph(AppGlyph.caseSolid), findsNothing);
    expect(findGlyph(AppGlyph.caseBroken), findsOneWidget);
  });

  testWidgets('with animations off the case change takes 100 ms', (tester) async {
    await _pump(tester, caseKind: CaseKind.wipe, still: true);
    await _pump(tester, still: true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(findGlyph(AppGlyph.caseBroken), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 51));
    expect(findGlyph(AppGlyph.caseBroken), findsNothing);
    expect(findGlyph(AppGlyph.caseSolid), findsOneWidget);
  });

  testWidgets('the light goes amber to jade over 150 ms', (tester) async {
    await _pump(tester, live: false);
    expect(_lightColour(tester), C.warning);
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_lightColour(tester), isNot(C.warning));
    expect(_lightColour(tester), isNot(C.jade));
    await tester.pump(const Duration(milliseconds: 76));
    expect(_lightColour(tester), C.jade);
  });

  testWidgets('with animations off the light takes 100 ms', (tester) async {
    await _pump(tester, live: false, still: true);
    await _pump(tester, still: true);
    await tester.pump(const Duration(milliseconds: 101));
    expect(_lightColour(tester), C.jade);
  });
}
