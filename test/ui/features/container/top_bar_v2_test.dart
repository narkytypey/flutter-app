import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/core/host_text.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

const _host = 'forum.example.com';

Future<void> _pump(
  WidgetTester tester, {
  String host = _host,
  String routeLabel = 'SOCKS5',
  CaseKind caseKind = CaseKind.keep,
  bool tor = false,
  SecurityLevel securityLevel = SecurityLevel.standard,
  bool loading = false,
  double scale = 1.0,
  Size size = const Size(320, 568),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        // Scrolls so the test font, far wider than Plex Sans, never makes a
        // very long host overflow the test screen itself.
        body: SingleChildScrollView(child: Column(children: [
          ContainerTopBar(
            host: host,
            routeLabel: routeLabel,
            live: true,
            loading: loading,
            onEditAddress: () {},
            onStop: () {},
            onReload: () {},
            onSiteDetails: () {},
            openCount: 2,
            onOpenSwitcher: () {},
            onMenu: () {},
            caseKind: caseKind,
            tor: tor,
            securityLevel: securityLevel,
          ),
        ])),
      ),
    ),
  ));
}

RenderParagraph _hostParagraph(WidgetTester tester) => tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(_host), matching: find.byType(RichText)));

void main() {
  testWidgets('at 320 x 568 and 2.0 the whole host is drawn, never ellipsized', (tester) async {
    await _pump(tester, scale: 2.0);

    expect(tester.takeException(), isNull);
    final paragraph = _hostParagraph(tester);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
    expect(paragraph.maxLines, isNull);
    // Every character is laid out: the dots only gain a break opportunity.
    expect(paragraph.text.toPlainText(includeSemanticsLabels: false), breakAfterDots(_host));
    // The host still reads as itself.
    expect(find.text(_host), findsOneWidget);
    // The pill grew to hold it.
    expect(tester.getSize(find.byKey(const Key('address-pill'))).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('a long host at 2.0 wraps over several lines in a taller pill', (tester) async {
    const long = 'very-long-subdomain.of-a-forum.example.co.uk';
    await _pump(tester, host: long, scale: 2.0);

    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(long), matching: find.byType(RichText)));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.byKey(const Key('address-pill'))).height, greaterThan(48));
  });

  testWidgets('the case is solid for keep, broken for wipe and throwaway, double on Tor',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(findGlyph(AppGlyph.caseSolid), findsOneWidget);
    expect(find.bySemanticsLabel('Keep for this site'), findsOneWidget);

    await _pump(tester, caseKind: CaseKind.wipe);
    expect(findGlyph(AppGlyph.caseBroken), findsOneWidget);
    expect(find.bySemanticsLabel('Wipe on exit'), findsOneWidget);

    await _pump(tester, caseKind: CaseKind.throwaway);
    expect(findGlyph(AppGlyph.caseBroken), findsOneWidget);
    expect(find.bySemanticsLabel('Wipe on exit'), findsOneWidget);

    await _pump(tester, tor: true, routeLabel: 'Tor');
    // The case cross-fades (restyle v2 §7); the old one is gone once it ends.
    await tester.pumpAndSettle();
    expect(findGlyph(AppGlyph.caseDouble), findsOneWidget);
    expect(findGlyph(AppGlyph.caseSolid), findsNothing);
    expect(find.bySemanticsLabel('Keep for this site'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the shield follows the security level, never in jade', (tester) async {
    for (final (level, glyph) in [
      (SecurityLevel.standard, AppGlyph.shield),
      (SecurityLevel.safer, AppGlyph.shieldHalf),
      (SecurityLevel.safest, AppGlyph.shieldFull),
    ]) {
      await _pump(tester, securityLevel: level);
      expect(findGlyph(glyph), findsOneWidget, reason: '$level');
      expect(tester.widget<AppIcon>(findGlyph(glyph)).color, isNot(C.jade));
    }
  });

  testWidgets('shield, reload, stop and ☰ are each at least 48 x 48, and there is no panic',
      (tester) async {
    await _pump(tester);
    // User's ruling, 2026-10-10: panic is started only by flipping face down.
    expect(findIconTap('Panic'), findsNothing);
    final count = tester.getSize(find.byKey(const Key('open-sessions-target')));
    expect(count.width >= 48 && count.height >= 48, isTrue);
    for (final label in ['Site details', 'Reload', 'Menu']) {
      final size = tester.getSize(findIconTap(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    await _pump(tester, loading: true);
    final stop = tester.getSize(findIconTap('Stop'));
    expect(stop.width >= 48 && stop.height >= 48, isTrue);
  });

  // Option A of the user's ruling, 2026-10-10: the open count and ☰ beside
  // the pill, which keeps reload and the shield beside the host on a phone.
  for (final width in [360.0, 412.0]) {
    testWidgets('at $width wide, reload and the shield sit beside the host, not under it',
        (tester) async {
      await _pump(tester, size: Size(width, 800));

      expect(tester.takeException(), isNull);
      final host = tester.getRect(find.text(_host));
      final shield = tester.getRect(findIconTap('Site details'));
      expect(shield.left, greaterThan(host.right), reason: 'beside the host');
      expect(shield.top, lessThan(host.bottom), reason: 'on the same row');
    });
  }

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
    (const Size(320, 568), 2.0),
    (const Size(360, 640), 1.3),
    (const Size(915, 412), 1.0),
  ]) {
    testWidgets('at ${size.width.toInt()}x${size.height.toInt()} and $scale the bar fits',
        (tester) async {
      await _pump(tester, size: size, scale: scale);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(findIconTap('Menu')).right, lessThanOrEqualTo(size.width));
    });
  }

  testWidgets("the light is the pill's only jade", (tester) async {
    await _pump(tester);
    for (final icon in tester.widgetList<AppIcon>(find.byType(AppIcon))) {
      expect(icon.color, isNot(C.jade));
    }
    final jade = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == C.jade);
    expect(jade, hasLength(1));
  });
}
