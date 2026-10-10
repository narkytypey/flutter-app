import 'package:container/domain/models/open_step.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:container/ui/features/container/views/opening_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cyberpunk spec §3: the live and opening lights glow in their own colour,
/// dark palette only; nothing else does.
BoxShadow _glowOf(Color c) => BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6);

BoxDecoration _railDecoration(WidgetTester tester, Finder rail) => tester
    .widget<Container>(find.descendant(of: rail, matching: find.byType(Container)))
    .decoration! as BoxDecoration;

/// The pill dot as painted (mid-animation values included).
BoxDecoration _pillDot(WidgetTester tester) {
  final dot = find.descendant(
      of: find.byKey(const Key('address-pill')), matching: find.byType(AnimatedContainer));
  return tester
      .widget<DecoratedBox>(find.descendant(of: dot, matching: find.byType(DecoratedBox)).first)
      .decoration as BoxDecoration;
}

Widget _topBar({required bool live, bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 640), disableAnimations: still),
        child: Scaffold(
          body: Column(children: [
            ContainerTopBar(
              host: 'example.com',
              routeLabel: 'SOCKS5',
              live: live,
              loading: false,
              onEditAddress: () {},
              onStop: () {},
              onReload: () {},
              onSiteDetails: () {},
              openCount: 1,
              onOpenSwitcher: () {},
              onMenu: () {},
              caseKind: CaseKind.keep,
              tor: false,
              securityLevel: SecurityLevel.standard,
            ),
          ]),
        ),
      ),
    );

void main() {
  tearDown(() => C.use(Brightness.dark));

  test('C.glow is one 60 % shadow, blur 6, in the light\'s colour, dark only', () {
    C.use(Brightness.dark);
    expect(Palette.dark.glow, isTrue);
    expect(Palette.light.glow, isFalse);
    expect(C.glow(C.jade), [_glowOf(C.jade)]);
    C.use(Brightness.light);
    expect(C.glow(C.jade), isNull);
  });

  testWidgets('a live and an opening light glow in their own colour', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Row(children: [StatusRail(live: true), StatusRail(live: false, opening: true)])));
    final rails = find.byType(StatusRail);
    expect(_railDecoration(tester, rails.at(0)).boxShadow, [_glowOf(C.jade)]);
    expect(_railDecoration(tester, rails.at(1)).boxShadow, [_glowOf(C.warning)]);
  });

  testWidgets('idle has no glow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Row(children: [StatusRail(live: false)])));
    expect(_railDecoration(tester, find.byType(StatusRail)).boxShadow, isNull);
  });

  testWidgets('no glow under the light palette', (tester) async {
    C.use(Brightness.light);
    await tester.pumpWidget(const MaterialApp(home: Row(children: [StatusRail(live: true)])));
    expect(_railDecoration(tester, find.byType(StatusRail)).boxShadow, isNull);
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, anyOf(isNull, isEmpty));
  });

  testWidgets("the address pill's dot glows jade when live", (tester) async {
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });

  testWidgets('opening to live ends on the jade glow', (tester) async {
    await tester.pumpWidget(_topBar(live: false));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.warning)]);
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).color, C.jade);
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });

  testWidgets('glow holds with animations off', (tester) async {
    await tester.pumpWidget(_topBar(live: true, still: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });

  testWidgets("8a's opening dot glows amber, like the pill it becomes", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OpeningBody(
        host: 'example.com',
        steps: const [OpenStep('Filter lists loaded', OpenStepState.running)],
        progress: 0.2,
        onCancel: () {},
      ),
    ));
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle && d.color == C.warning)
        .toList();
    expect(dots, hasLength(1));
    expect(dots.single.boxShadow, [_glowOf(C.warning)]);
  });
}
