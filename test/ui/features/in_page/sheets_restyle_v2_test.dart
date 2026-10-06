import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/features/dashboard/views/site_row_menu.dart';
import 'package:container/ui/features/in_page/views/held_download_sheet.dart';
import 'package:container/ui/features/in_page/views/permission_request_sheet.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';
import 'package:container/ui/features/in_page/views/site_sheet.dart';
import 'package:container/ui/features/in_page/views/tunnel_dropped_screen.dart';

/// Restyle v2 (Plan 23 Task 5): `6a`, `6c`, `7b`, `7c`, `8b`, `8c`.
void main() {
  const longHost = 'a-very-long-subdomain.of-an-example-site.example.com';

  PillButton pill(WidgetTester tester, String label) => tester.widget<PillButton>(
      find.ancestor(of: find.text(label), matching: find.byType(PillButton)));

  /// A host laid out to wrap after its dots (restyle v2 §1.6): the text the
  /// screen lays out carries U+200B after each dot, nothing cuts it short.
  void expectWraps(WidgetTester tester, String plain) {
    final text = tester.widget<Text>(find.text(plain));
    expect(text.maxLines, isNull, reason: plain);
    expect(text.overflow, isNot(TextOverflow.ellipsis), reason: plain);
    final laidOut = text.textSpan!.toPlainText(includeSemanticsLabels: false);
    expect(laidOut, contains('.​'), reason: plain);
  }

  Widget sheetHost(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('6a', () {
    testWidgets('Keep blocked is the jade action, Allow once is neutral', (tester) async {
      final seen = <PermissionDecision>[];
      await tester.pumpWidget(sheetHost(PermissionRequestSheet(
          host: longHost, kind: PermissionKind.camera, onDecision: seen.add)));

      expect(pill(tester, 'Keep blocked').tone, PillTone.primary);
      expect(pill(tester, 'Allow once').tone, PillTone.neutral);
      expect(pill(tester, 'Allow while this site is open').tone, PillTone.neutral);
      // Same words, same order, same handlers.
      expect(
        tester.widgetList<PillButton>(find.byType(PillButton)).map((p) => p.label),
        ['Allow once', 'Allow while this site is open', 'Keep blocked'],
      );
      await tester.tap(find.text('Allow once'));
      await tester.tap(find.text('Keep blocked'));
      expect(seen, [PermissionDecision.allowOnce, PermissionDecision.keepBlocked]);
      expectWraps(tester, '$longHost wants ${PermissionKind.camera.phrase}');
    });
  });

  group('6c', () {
    Widget siteSheet() => SiteSheet(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: '$longHost · Personal',
          proxyDescriptor: 'SOCKS5 · 127.0.0.1:9050',
          onProxy: () {},
          cookiesDescriptor: 'Wipe on exit',
          blockedCount: 164,
          forceDark: true,
          desktopView: false,
          onEdit: () {},
          onForceDarkChanged: (_) {},
          onDesktopViewChanged: (_) {},
          onCloseAndWipe: () {},
          securityLevelValue: 'Standard · default',
          onSecurityLevel: () {},
          categoryCounts: const {},
          blockWebRtc: true,
          blockTrackers: true,
          antiFingerprinting: false,
          onBlockWebRtcChanged: (_) {},
          onBlockTrackersChanged: (_) {},
          onAntiFingerprintingChanged: (_) {},
          permissions: const [],
          onRevoke: (_) {},
        );

    testWidgets('switches are v2 toggles, none jade; Edit is the one jade', (tester) async {
      await tester.pumpWidget(sheetHost(siteSheet()));

      expect(find.byType(AppToggle), findsNWidgets(5));
      for (final box in tester.widgetList<Container>(find.descendant(
          of: find.byType(AppToggle), matching: find.byType(Container)))) {
        final d = box.decoration;
        if (d is BoxDecoration) expect(d.color, isNot(C.jade));
      }
      final jade = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == C.jade)
          .map((t) => t.data);
      expect(jade, ['Edit']);
    });

    testWidgets('the blocked count is Mono and the subtitle host wraps', (tester) async {
      await tester.pumpWidget(sheetHost(siteSheet()));

      expect(tester.widget<Text>(find.text('164 requests')).style!.fontFamily, 'IBMPlexMono');
      expectWraps(tester, '$longHost · Personal');
    });
  });

  testWidgets('7b: both wipe rows are danger, and the subtitle host wraps', (tester) async {
    await tester.pumpWidget(sheetHost(SiteRowMenu(
        monogram: 'Fr',
        name: 'Forum',
        subtitle: longHost,
        onAction: (_) {},
        onCancel: () {})));

    expect(tester.widget<Text>(find.text("Wipe this site's data")).style!.color, C.danger);
    expect(tester.widget<Text>(find.text('Remove site')).style!.color, C.danger);
    expectWraps(tester, longHost);
  });

  testWidgets('7c: Discard stays the jade action, and the host wraps', (tester) async {
    await tester.pumpWidget(sheetHost(HeldDownloadSheet(
      download: const HeldDownload(
        kindLabel: 'PDF',
        fileName: 'statement-june.pdf',
        sizeBytes: null,
        sourceHost: longHost,
      ),
      onDecision: (_) {},
    )));

    expect(pill(tester, 'Discard').tone, PillTone.primary);
    expect(pill(tester, 'Keep inside this container').tone, PillTone.neutral);
    expectWraps(tester, 'from $longHost');
  });

  group('8b', () {
    Widget screen({bool canGoDirect = true}) => MaterialApp(
          home: ProxyUnreachableScreen(
            host: longHost,
            siteName: 'Forum',
            failure: RouteFailure.proxyUnreachable,
            tunnelDescriptor: 'socks5 · 127.0.0.1:9050',
            lastWorkedLabel: '2 hours ago',
            onTryAgain: () {},
            onChangeProxySettings: () {},
            onOpenWithoutTunnel: canGoDirect ? () {} : null,
          ),
        );

    testWidgets('Open without the tunnel is danger text, 24 dp below the others',
        (tester) async {
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(screen());

      expect(pill(tester, 'Try again').tone, PillTone.primary);
      expect(pill(tester, 'Change proxy settings').tone, PillTone.neutral);
      final open = pill(tester, 'Open without the tunnel');
      expect(open.tone, PillTone.dangerText);
      expect(open.sublabel, 'This site will see your real IP');

      final change = tester.getRect(find.ancestor(
          of: find.text('Change proxy settings'), matching: find.byType(PillButton)));
      final direct = tester.getRect(find.ancestor(
          of: find.text('Open without the tunnel'), matching: find.byType(PillButton)));
      expect(direct.top - change.bottom, greaterThanOrEqualTo(24));
    });

    testWidgets('it is absent when the site cannot go direct', (tester) async {
      await tester.pumpWidget(screen(canGoDirect: false));
      expect(find.text('Open without the tunnel'), findsNothing);
    });

    testWidgets('the host wraps in the header', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(screen());
      expectWraps(tester, longHost);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('8c: the banner is the danger wash, Reconnect jade, the host wraps',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: TunnelDroppedScreen(
        host: longHost,
        droppedAgoLabel: '12 seconds ago',
        onReconnect: () {},
        onCloseAndWipe: () {},
      ),
    ));

    expectWraps(tester, longHost);
    final banner = find.ancestor(
        of: find.text('Tunnel dropped'), matching: find.byType(Container));
    expect(
      tester.widgetList<Container>(banner).any((c) =>
          c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).color == C.dangerSurface),
      isTrue,
    );
    final reconnect = find.ancestor(of: find.text('Reconnect'), matching: find.byType(Material));
    expect(tester.widget<Material>(reconnect.first).color, C.jade);
    expect(tester.widget<Text>(find.text('Reconnect')).style!.color, C.onJade);
    expect(tester.takeException(), isNull);
  });
}
