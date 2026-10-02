import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/add_site/view_models/add_site_view.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
];

Future<void> _pump(WidgetTester tester, {Site? initial, ValueChanged<Site>? onSave}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(initial: initial, workspaces: _workspaces, onSave: onSave ?? (_) {}),
  ));
  await tester.tap(find.text('Network'));
  await tester.pumpAndSettle();
}

TextField _textField(WidgetTester tester, String key) => tester.widget<TextField>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)));

Site _build({
  Site? initial,
  ProxyMode proxyMode = ProxyMode.socks5,
  String proxyUser = 'alice',
  String proxyPassword = 's3cret',
  bool proxyLoginPerSite = false,
}) =>
    buildSite(
      initial: initial, url: 'https://forum.example.com', name: 'Forum', monogram: 'Fr',
      workspaceId: 'ws-personal', cookiePolicy: CookiePolicy.keep,
      proxyMode: proxyMode,
      proxyHost: proxyMode == ProxyMode.direct ? null : '127.0.0.1',
      proxyPort: proxyMode == ProxyMode.direct ? null : 9050,
      proxyUser: proxyUser, proxyPassword: proxyPassword, proxyLoginPerSite: proxyLoginPerSite,
      blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
      allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
      requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
      forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
    );

void main() {
  group('buildSite keeps a typed login only when it can be used (ruling 8)', () {
    test('a typed login on a proxied site is kept, the password exactly as typed', () {
      final site = _build(proxyPassword: ' s3cret ');
      expect(site.proxyUser, 'alice');
      expect(site.proxyPassword, ' s3cret ');
      expect(site.proxyLoginPerSite, isFalse);
    });

    // Review Focus 5.
    test('per-site login drops a typed one', () {
      final site = _build(proxyLoginPerSite: true);
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
      expect(site.proxyLoginPerSite, isTrue);
    });

    test('a direct site keeps no login and no per-site choice', () {
      final site = _build(proxyMode: ProxyMode.direct, proxyLoginPerSite: true);
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
      expect(site.proxyLoginPerSite, isFalse);
    });

    test('a password without a user is not kept', () {
      final site = _build(proxyUser: '');
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
    });
  });

  // Privacy-controls spec §2.1: the form has no level control, and saving it
  // keeps whatever the site had.
  test("saving the form keeps the site's own level, and a new site follows the default", () {
    final own = _build().withSecurityLevel(SecurityLevel.safest);
    expect(_build(initial: own).securityLevel, SecurityLevel.safest);
    expect(_build().securityLevel, isNull);
  });

  testWidgets('the login block shows only while the proxy is on', (tester) async {
    await _pump(tester);
    expect(find.text('Separate login per site'), findsNothing);
    expect(find.text('USERNAME'), findsNothing);

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    expect(find.text('Separate login per site'), findsOneWidget);
    expect(find.text('Tor gives this site its own circuit'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });

  testWidgets('per-site login hides the two fields', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('proxy-login-per-site')));
    await tester.pumpAndSettle();

    expect(find.text('USERNAME'), findsNothing);
    expect(find.text('PASSWORD'), findsNothing);
  });

  testWidgets('the password is masked and each field takes 255 characters', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'proxy-password').obscureText, isTrue);
    expect(_textField(tester, 'proxy-user').obscureText, isFalse);

    await tester.enterText(find.byKey(const Key('proxy-user')), 'u' * 300);
    await tester.enterText(find.byKey(const Key('proxy-password')), 'p' * 300);
    expect(_textField(tester, 'proxy-user').controller!.text, hasLength(255));
    expect(_textField(tester, 'proxy-password').controller!.text, hasLength(255));
  });

  testWidgets('saving keeps the typed login', (tester) async {
    Site? saved;
    await _pump(tester, onSave: (s) => saved = s);
    // Save stays inert until the address is one the engine would load.
    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-site-address')), 'https://forum.example.com');
    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('proxy-user')), 'alice');
    await tester.enterText(find.byKey(const Key('proxy-password')), 's3cret');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved!.proxyUser, 'alice');
    expect(saved!.proxyPassword, 's3cret');
    expect(saved!.proxyLoginPerSite, isFalse);
  });

  testWidgets('editing a site, or saving a throwaway, starts from its login', (tester) async {
    const existing = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888,
      proxyUser: 'alice', proxyPassword: 's3cret',
    );
    Site? saved;
    await _pump(tester, initial: existing, onSave: (s) => saved = s);

    expect(_textField(tester, 'proxy-user').controller!.text, 'alice');
    expect(_textField(tester, 'proxy-password').controller!.text, 's3cret');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.proxyUser, 'alice');
    expect(saved!.proxyPassword, 's3cret');
  });

  testWidgets('a per-site site opens with the toggle on and no fields', (tester) async {
    const existing = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyLoginPerSite: true,
    );
    await _pump(tester, initial: existing);
    expect(find.text('Separate login per site'), findsOneWidget);
    expect(find.text('USERNAME'), findsNothing);
  });
}
