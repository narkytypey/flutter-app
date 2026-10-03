import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/settings/views/default_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

/// [DefaultRouteScreen] pushed over a home route, so leaving it is a real pop.
Future<List<ProxyRoute>> _pump(WidgetTester tester, ProxyRoute initial) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  final done = <ProxyRoute>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => DefaultRouteScreen(initial: initial, onDone: done.add),
        )),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return done;
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("it is titled Default route and holds the route fields only", (tester) async {
    await _pump(tester, ProxyRoute.direct);

    expect(find.text('Default route'), findsOneWidget);
    expect(findIconTap('Back'), findsOneWidget);
    expect(find.text('Route through proxy'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('PORT'), findsOneWidget);
    // Per site, not route (spec §7), and no "This site only" (plan D2).
    expect(find.text('Block WebRTC'), findsNothing);
    expect(find.text('Block trackers and ads'), findsNothing);
    expect(find.text('This site only'), findsNothing);
  });

  testWidgets('it starts from the stored route', (tester) async {
    await _pump(tester, const ProxyRoute(
        mode: ProxyMode.http, host: 'proxy.lan', port: 3128, user: 'alice', password: 'pw'));

    expect(find.text('proxy.lan'), findsOneWidget);
    expect(find.text('3128'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Separate login per site'), findsOneWidget);
  });

  testWidgets('the back icon leaves with the route as set, ruling 8 applied', (tester) async {
    final done = await _pump(tester, ProxyRoute.direct);

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pump();
    await tester.enterText(
        find.descendant(of: find.byKey(const Key('proxy-user')), matching: find.byType(TextField)),
        'alice');
    await tester.enterText(
        find.descendant(of: find.byKey(const Key('proxy-password')), matching: find.byType(TextField)),
        'pw');
    await tester.tap(findIconTap('Back'));
    await tester.pumpAndSettle();

    expect(done, [
      const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw'),
    ]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('system back saves too; turning the proxy off is Direct', (tester) async {
    final done = await _pump(tester,
        const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050));

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pump();
    await _systemBack(tester);

    expect(done, [ProxyRoute.direct]);
  });
}
