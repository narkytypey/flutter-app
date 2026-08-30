import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/dashboard_body.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';

final _now = DateTime(2026, 8, 30, 9, 10);

Site _site(String id, String name, String mono, String url, Duration ago,
        {CookiePolicy cookies = CookiePolicy.keep,
        ProxyMode proxy = ProxyMode.direct,
        bool pin = false}) =>
    Site(
      id: id, workspaceId: 'ws', name: name, monogram: mono, url: url,
      cookiePolicy: cookies, proxyMode: proxy, requirePin: pin,
      lastVisitedAt: _now.subtract(ago),
    );

DashboardView _personal({Set<String> open = const {'st-notes', 'st-webmail'}}) {
  return DashboardView.from(
    workspace: const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
    sites: [
      _site('st-notes', 'Notes', 'Nt', 'https://notes.example.org',
          const Duration(seconds: 10), proxy: ProxyMode.socks5),
      _site('st-webmail', 'Webmail', 'Wm', 'https://mail.example.net',
          const Duration(minutes: 14)),
      _site('st-forum', 'Forum', 'Fr', 'https://forum.example.com',
          const Duration(hours: 2), cookies: CookiePolicy.wipeOnExit),
      _site('st-bank', 'Bank', 'Bk', 'https://bank.example.com',
          const Duration(days: 3), pin: true),
    ],
    openSiteIds: open,
    leakCount: 0,
    now: _now,
  );
}

Future<void> _pump(WidgetTester tester, DashboardView view,
    {void Function(String)? onOpenSite, VoidCallback? onAddSite}) {
  return tester.pumpWidget(MaterialApp(
    home: DashboardBody(
      view: view,
      onWorkspaceTap: () {},
      onAddSite: onAddSite ?? () {},
      onSearch: () {},
      onOpenSite: onOpenSite ?? (_) {},
      onSiteMenu: (_) {},
    ),
  ));
}

void main() {
  testWidgets('the bar names the workspace and counts sessions and leaks',
      (tester) async {
    await _pump(tester, _personal());

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('sites are grouped into OPEN NOW and IDLE', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('OPEN NOW'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);

    final openLabel = tester.getTopLeft(find.text('OPEN NOW')).dy;
    final idleLabel = tester.getTopLeft(find.text('IDLE')).dy;
    expect(tester.getTopLeft(find.text('Notes')).dy, greaterThan(openLabel));
    expect(tester.getTopLeft(find.text('Notes')).dy, lessThan(idleLabel));
    expect(tester.getTopLeft(find.text('Forum')).dy, greaterThan(idleLabel));
  });

  testWidgets('each row shows host and descriptor, and its age', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('notes.example.org · socks5'), findsOneWidget);
    expect(find.text('mail.example.net · direct'), findsOneWidget);
    expect(find.text('forum.example.com · ephemeral'), findsOneWidget);
    expect(find.text('bank.example.com · pin required'), findsOneWidget);

    expect(find.text('now'), findsOneWidget);
    expect(find.text('14m'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
  });

  testWidgets('an open row is brighter than an idle one', (tester) async {
    await _pump(tester, _personal());

    expect(tester.widget<Text>(find.text('Notes')).style!.color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Forum')).style!.color, C.textTertiary);
  });

  testWidgets('tapping a row opens that site', (tester) async {
    final opened = <String>[];
    await _pump(tester, _personal(), onOpenSite: opened.add);

    await tester.tap(find.text('Forum'));
    expect(opened, ['st-forum']);
  });

  testWidgets('with nothing open the OPEN NOW group is absent', (tester) async {
    await _pump(tester, _personal(open: const {}));

    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.text('IDLE'), findsOneWidget);
    expect(find.text('0 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('the footer offers Add site and reports taps', (tester) async {
    var added = 0;
    await _pump(tester, _personal(), onAddSite: () => added++);

    expect(find.text('+ Add site'), findsOneWidget);
    await tester.tap(find.text('+ Add site'));
    expect(added, 1);
  });

  testWidgets('a wipe-on-exit workspace shows its rule instead of counts',
      (tester) async {
    await _pump(
      tester,
      DashboardView.from(
        workspace: const Workspace(
            id: 'ws', name: 'Ephemeral', markerIndex: 4,
            storageRule: StorageRule.wipeOnExit),
        sites: const [],
        openSiteIds: const {},
        leakCount: 0,
        now: _now,
      ),
    );

    expect(find.text('WIPES ON EXIT'), findsOneWidget);
    expect(find.textContaining('SESSIONS'), findsNothing);
  });
}
