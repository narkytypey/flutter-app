import 'dart:async';

import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/dashboard/views/sites_tab.dart';
import 'package:container/ui/features/settings/view_models/providers.dart'
    show defaultRouteProvider, defaultRouteSettingKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

const _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p-forum',
);
const _ledger = Site(
  id: 'ledger', workspaceId: 'w2', name: 'Ledger', monogram: 'Lg',
  url: 'https://ledger.example.org', profileId: 'p-ledger',
);

const _socks = ProxyRoute(
    mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');

Map<String, String> _route(ProxyRoute route) => {defaultRouteSettingKey: route.toStored()};

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('dashboard-search')), text);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a word lists saved sites from every workspace, then the search row', (tester) async {
    await pumpDashboard(tester, sites: const [_forum, _ledger]);

    await _type(tester, 'example');

    expect(find.text('SAVED SITES'), findsOneWidget);
    expect(find.text('ledger.example.org · Work'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('ITS OWN CONTAINER'), findsNWidgets(2));
    expect(find.text('Search DuckDuckGo for “example”'), findsOneWidget);
    expect(find.text('THIS CONTAINER'), findsNothing);
  });

  testWidgets('an unsaved address on a direct default opens a throwaway with no opener',
      (tester) async {
    final h = await pumpDashboard(tester);

    await _type(tester, 'news.example.org/today');
    expect(find.text('THROWAWAY'), findsNWidgets(2));
    await _enter(tester);

    final id = h.engine.openedAsThrowaway.single;
    final opened = h.engine.openedSites[id]!;
    expect(opened.url, 'https://news.example.org/today');
    expect(opened.proxyMode, ProxyMode.direct);
    expect(opened.workspaceId, 'w1', reason: 'the viewed chip');
    expect(h.tabs.byId(id)!.openerSiteId, isNull);
    expect(h.tabs.viewedSiteId, id);
    expect(find.byType(ContainerRoute), findsOneWidget);
  });

  testWidgets('on a SOCKS5 default the throwaway goes out on it, login and all', (tester) async {
    final h = await pumpDashboard(tester, settings: _route(_socks));

    await _type(tester, 'news.example.org');
    expect(find.text('THROWAWAY · SOCKS5'), findsNWidgets(2));
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect((opened.proxyMode, opened.proxyHost, opened.proxyPort),
        (ProxyMode.socks5, '127.0.0.1', 9050));
    expect((opened.proxyUser, opened.proxyPassword), ('alice', 'pw'));
  });

  testWidgets('with per-site login each throwaway gets its own', (tester) async {
    final h = await pumpDashboard(tester,
        settings: _route(const ProxyRoute(
            mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, loginPerSite: true)));

    await _type(tester, 'news.example.org');
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect(opened.proxyLoginPerSite, isTrue);
    expect(opened.proxyUser, isNull);
  });

  testWidgets("a saved site's host opens its own container, not a throwaway", (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);

    await _type(tester, 'forum.example.com/latest');
    await _enter(tester);

    expect(h.engine.openedAsThrowaway, isEmpty);
    expect(h.tabs.viewedSiteId, 'forum');
    expect(h.engine.openedInitialUrls['forum'], 'https://forum.example.com/latest');
  });

  testWidgets('a saved site that is already open is shown, not opened twice', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);
    await tester.runAsync(() => h.registry.view(_forum));
    h.registry.showDashboard();
    await tester.pumpAndSettle();

    await _type(tester, 'forum.example.com/latest');
    await _enter(tester);

    expect(h.tabs.containers.map((c) => c.siteId), ['forum']);
    expect(h.tabs.viewedSiteId, 'forum');
    expect(h.engine.loaded.single.url, 'https://forum.example.com/latest');
  });

  testWidgets('words open the search engine on the default route', (tester) async {
    final h = await pumpDashboard(tester);

    await _type(tester, 'two words');
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect(opened.url, startsWith('https://duckduckgo.com/?q=two'));
  });

  testWidgets("a throwaway counts under the viewed chip's workspace", (tester) async {
    final h = await pumpDashboard(tester);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await _type(tester, 'news.example.org');
    await _enter(tester);

    expect(h.engine.openedSites[h.engine.openedAsThrowaway.single]!.workspaceId, 'w2');
  });

  testWidgets('back from its first page closes and wipes it, to the dashboard, '
      'even with another container open', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);
    await tester.runAsync(() => h.registry.view(_forum));
    h.registry.showDashboard();
    await tester.pumpAndSettle();
    await _type(tester, 'news.example.org');
    await _enter(tester);
    final id = h.engine.openedAsThrowaway.single;

    await systemBack(tester);

    expect(h.engine.closedWith[id], isTrue, reason: 'closed and wiped');
    expect(h.tabs.byId(id), isNull);
    expect(h.tabs.byId('forum'), isNotNull, reason: 'the other stays open');
    expect(find.byType(SitesTab), findsOneWidget);
    expect(find.byType(ContainerRoute), findsNothing);
  });

  testWidgets('back while searching clears the field and stays', (tester) async {
    await pumpDashboard(tester, sites: const [_forum]);
    await _type(tester, 'forum');
    expect(find.text('SAVED SITES'), findsOneWidget);

    await systemBack(tester);

    expect(find.text('SAVED SITES'), findsNothing);
    expect(find.text('Forum'), findsOneWidget, reason: 'the list is back');
    expect(tester.widget<TextField>(find.byKey(const Key('dashboard-search'))).controller!.text,
        isEmpty);
  });

  testWidgets('a tap outside the rows ends the search', (tester) async {
    await pumpDashboard(tester, sites: const [_forum]);
    await _type(tester, 'forum');

    await tester.tap(find.text('Nothing is fetched while you type.'));
    await tester.pumpAndSettle();

    expect(find.text('SAVED SITES'), findsNothing);
  });

  testWidgets('nothing is offered or opened before the default route is read', (tester) async {
    final h = await pumpDashboard(tester, overrides: [
      defaultRouteProvider.overrideWith((ref) => Completer<ProxyRoute>().future),
    ]);

    await _type(tester, 'news.example.org');
    expect(find.text('ADDRESS'), findsNothing);
    expect(find.textContaining('THROWAWAY'), findsNothing);
    await _enter(tester);

    expect(h.tabs.containers, isEmpty);
  });

  testWidgets("+ opens a new site's form on the viewed workspace and the default route",
      (tester) async {
    await pumpDashboard(tester, settings: _route(_socks));
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.tap(findIconTap('Add site'));
    await tester.pumpAndSettle();

    final form = tester.widget<AddSiteScreen>(find.byType(AddSiteScreen));
    expect(form.initial, isNull);
    expect(form.initialWorkspaceId, 'w2');
    expect(form.defaultRoute, _socks);
  });

  testWidgets('saving that form adds the site to the vault', (tester) async {
    final h = await pumpDashboard(tester);
    await tester.tap(findIconTap('Add site'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(h.sites.upserts.single.name, 'example.com');
    expect(h.sites.upserts.single.workspaceId, 'w1');
    expect(find.byType(AddSiteScreen), findsNothing);
  });
}
