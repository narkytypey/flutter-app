import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';

import '../../../support/glyph_finders.dart';

void main() {
  Widget host({
    RouteFailure failure = RouteFailure.proxyUnreachable,
    VoidCallback? onTryAgain,
    VoidCallback? onChangeProxySettings,
    VoidCallback? onOpenWithoutTunnel,
  }) {
    return MaterialApp(
      home: ProxyUnreachableScreen(
        host: 'forum.example.com',
        siteName: 'Forum',
        failure: failure,
        tunnelDescriptor: 'socks5 · 127.0.0.1:9050',
        lastWorkedLabel: '2 hours ago',
        onTryAgain: onTryAgain ?? () {},
        onChangeProxySettings: onChangeProxySettings ?? () {},
        onOpenWithoutTunnel: onOpenWithoutTunnel ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim for the drawn failure', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Proxy did not answer'), findsOneWidget);
    expect(
      find.text(
        'Forum is set to go through socks5 · 127.0.0.1:9050 and nothing is '
        'listening there. The page was not loaded, so no request left your device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tunnel'), findsOneWidget);
    expect(find.text('socks5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Last worked'), findsOneWidget);
    expect(find.text('2 hours ago'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Change proxy settings'), findsOneWidget);
    expect(find.text('Open without the tunnel'), findsOneWidget);
    expect(find.text('This site will see your real IP'), findsOneWidget);
    // The top bar's marks stay decoration, as the canvas draws them: undimmed
    // and unlabelled (restyle spec §8).
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.back)).color, C.icon);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.reload)).color, C.icon);
    expect(findIconTap('Back'), findsNothing);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.refused)).color, C.danger);
    expect(tester.getSize(findGlyph(AppGlyph.refused)), const Size(20, 20));
  });

  testWidgets('a different failure headlines with its own refusal message', (tester) async {
    await tester.pumpWidget(host(failure: RouteFailure.proxyRefused));
    // Assert against Plan 3's function, not a copy of the string it returns.
    // A duplicated string keeps passing when Plan 3 rewords the message, then
    // fails here looking like a Plan 4 bug.
    expect(find.text(refusalMessage(RouteFailure.proxyRefused)), findsOneWidget);
  });

  testWidgets('an unsupported WebView shows the approved headline and hint', (tester) async {
    await tester.pumpWidget(host(failure: RouteFailure.unsupported));
    expect(find.text('This phone cannot route sites through a proxy'), findsOneWidget);
    expect(find.text('Update Android System WebView to open proxied sites.'), findsOneWidget);
  });

  testWidgets('each button reports its own callback', (tester) async {
    var tried = 0;
    var changed = 0;
    var opened = 0;
    await tester.pumpWidget(host(
      onTryAgain: () => tried++,
      onChangeProxySettings: () => changed++,
      onOpenWithoutTunnel: () => opened++,
    ));

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Change proxy settings'));
    await tester.tap(find.text('Open without the tunnel'));

    expect(tried, 1);
    expect(changed, 1);
    expect(opened, 1);
  });
}
