import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/add_site/views/form_toggle_row.dart';
import 'package:flutter/material.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/add_site/view_models/add_site_view.dart';
import 'package:flutter_test/flutter_test.dart';

Site _build({required String url, ProxyMode mode = ProxyMode.direct, String? host, int? port}) => buildSite(
      initial: null, url: url, name: 'Hidden', monogram: 'Hd', workspaceId: 'w',
      cookiePolicy: CookiePolicy.keep, proxyMode: mode, proxyHost: host, proxyPort: port,
      blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
      allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
      requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
      forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
    );

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
];

Future<void> _pumpForm(WidgetTester tester,
    {ValueChanged<Site>? onSave, ProxyRoute defaultRoute = ProxyRoute.direct}) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(
      initial: null,
      workspaces: _workspaces,
      initialWorkspaceId: null,
      defaultRoute: defaultRoute,
      onSave: onSave ?? (_) {},
    ),
  ));
}

FormToggleRow _row(WidgetTester tester, String title) => tester.widget<FormToggleRow>(
    find.ancestor(of: find.text(title), matching: find.byType(FormToggleRow)));

void main() {
  group('buildSite', () {
    test('a Tor site keeps no address and no typed login', () {
      final site = _build(url: 'https://example.com', mode: ProxyMode.tor, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
      expect(site.proxyPort, isNull);
      expect(site.proxyUser, isNull);
    });

    // Spec §5.3, plan D7.
    test('an onion address is never saved on Direct', () {
      final site = _build(url: 'http://abc.onion/');
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
    });

    test('an onion address on a proxy keeps that proxy', () {
      final site = _build(url: 'http://abc.onion/', mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.socks5);
      expect(site.proxyPort, 9050);
    });
  });

  group('the form', () {
    testWidgets('the Network tab has a Tor chip; choosing it shows the line in place of the fields',
        (tester) async {
      Site? saved;
      await _pumpForm(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proxy-enabled')));
      await tester.pump();

      await tester.tap(find.text('Tor'));
      await tester.pump();

      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
      expect(find.text('HOST'), findsNothing);
      expect(find.text('PORT'), findsNothing);
      expect(find.text('Separate login per site'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.proxyMode, ProxyMode.tor);
      expect(saved!.proxyHost, isNull);
    });

    // Spec 5.4.
    testWidgets('with Tor on, Block WebRTC is on and inert', (tester) async {
      await _pumpForm(tester, defaultRoute: ProxyRoute.tor);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      final row = _row(tester, 'Block WebRTC');
      expect(row.value, isTrue);
      expect(row.onChanged, isNull);

      // A tap on its label leaves it on, too.
      await tester.tap(find.text('Block WebRTC'));
      await tester.pump();
      expect(_row(tester, 'Block WebRTC').value, isTrue);
    });

    // Spec 5.3, plan D7.
    testWidgets('typing an onion address turns the proxy on, on Tor', (tester) async {
      Site? saved;
      await _pumpForm(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')),
          'http://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion');
      await tester.pump();

      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.proxyMode, ProxyMode.tor);
    });

    testWidgets('a default route of Tor starts the form on Tor', (tester) async {
      await _pumpForm(tester, defaultRoute: ProxyRoute.tor);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      expect(_row(tester, 'Route through proxy').value, isTrue);
      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
    });
  });
}
