import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/typography.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/dashboard/views/session_row.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/dashboard_body.dart';
import 'package:container/ui/features/dashboard/views/workspace_chips.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';

final _now = DateTime(2026, 8, 30, 9, 10);

Site _site(String id, String name, String mono, String url, Duration ago,
        {CookiePolicy cookies = CookiePolicy.keep,
        ProxyMode proxy = ProxyMode.direct,
        bool pin = false}) =>
    Site(
      id: id, workspaceId: 'ws', name: name, monogram: mono, url: url,
      profileId: 'p-$id',
      cookiePolicy: cookies, proxyMode: proxy, requirePin: pin,
      lastVisitedAt: _now.subtract(ago),
    );

DashboardView _personal({Set<String> open = const {'st-notes', 'st-bank'}}) {
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
    now: _now,
  );
}

DashboardView _empty() => DashboardView.from(
      workspace: const Workspace(
          id: 'ws', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
      sites: const [],
      openSiteIds: const {},
      now: _now,
    );

Future<void> _pump(WidgetTester tester, DashboardView view,
    {void Function(String)? onOpenSite, void Function(String)? onSiteMenu, Widget? cover}) {
  return tester.pumpWidget(MaterialApp(
    home: DashboardBody(
      view: view,
      chips: const [WorkspaceChip(id: 'ws', name: 'Personal', selected: true)],
      onPickWorkspace: (_) {},
      onEditWorkspace: (_) {},
      onNewWorkspace: () {},
      onOpenSite: onOpenSite ?? (_) {},
      onSiteMenu: onSiteMenu ?? (_) {},
      cover: cover,
      footer: const Text('the footer'),
    ),
  ));
}

void main() {
  testWidgets('no section titles and no count: the green dot alone (rulings 5)', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.text('IDLE'), findsNothing);
    expect(find.textContaining('SESSIONS'), findsNothing);
    // User's ruling 2026-10-02: the dashboard shows no leak count.
    expect(find.textContaining('LEAK'), findsNothing);
  });

  testWidgets('open sites come first, then the rest, most recent first (ruling 6)',
      (tester) async {
    await _pump(tester, _personal());

    final ys = [
      for (final name in ['Notes', 'Bank', 'Webmail', 'Forum'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
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

  testWidgets('a tap opens a site, a long-press its menu', (tester) async {
    final opened = <String>[];
    final menus = <String>[];
    await _pump(tester, _personal(), onOpenSite: opened.add, onSiteMenu: menus.add);

    await tester.tap(find.text('Forum'));
    await tester.longPress(find.text('Webmail'));
    expect(opened, ['st-forum']);
    expect(menus, ['st-webmail']);
  });

  testWidgets('the chips sit on top and the footer at the bottom', (tester) async {
    await _pump(tester, _personal());

    expect(tester.getTopLeft(find.text('Personal')).dy,
        lessThan(tester.getTopLeft(find.text('Notes')).dy));
    expect(tester.getTopLeft(find.text('the footer')).dy,
        greaterThan(tester.getTopLeft(find.text('Forum')).dy));
  });

  testWidgets('a wipe-on-exit workspace shows its rule (plan D3)', (tester) async {
    await _pump(tester, _empty());
    expect(find.text('WIPES ON EXIT'), findsOneWidget);
  });

  testWidgets('an empty workspace says so in one sentence', (tester) async {
    await _pump(tester, _empty());

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('Sites you open in this workspace leave nothing behind when '
          'you close the app.'),
      findsOneWidget,
    );
  });

  // The sentence is only true of a wipe-on-exit workspace (user's ruling
  // 2026-10-05).
  testWidgets('an empty workspace that keeps storage shows only its title', (tester) async {
    await _pump(
      tester,
      DashboardView.from(
        workspace: const Workspace(
            id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
        sites: const [],
        openSiteIds: const {},
        now: _now,
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.textContaining('leave nothing behind'), findsNothing);
  });

  testWidgets("a cover takes the list's place: the search field's suggestions", (tester) async {
    await _pump(tester, _personal(), cover: const Text('suggestions'));

    expect(find.text('suggestions'), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('Personal'), findsOneWidget, reason: 'the chips stay');
    expect(find.text('the footer'), findsOneWidget);
  });

  // Restyle v2 §8 `1b` (Plan 21 Task 2).
  testWidgets('v2: an idle row paints no light; an open one a jade light', (tester) async {
    await _pump(tester, _personal());

    StatusRail railOf(String name) => tester.widget<StatusRail>(find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(SessionRow)),
        matching: find.byType(StatusRail)));
    for (final idle in ['Webmail', 'Forum']) {
      final rail = railOf(idle);
      expect(rail.live, isFalse);
      expect(rail.showIdle, isFalse, reason: '1b rows say idle by the missing light');
    }
    expect(railOf('Notes').live, isTrue);
    expect(railOf('Notes').showIdle, isFalse);
  });

  testWidgets('v2: rows are at least 72 dp, names in the row-title roles', (tester) async {
    await _pump(tester, _personal());

    for (final row in tester.widgetList<SessionRow>(find.byType(SessionRow))) {
      expect(tester.getSize(find.byWidget(row)).height, greaterThanOrEqualTo(72));
    }
    expect(tester.widget<Text>(find.text('Notes')).style, T.rowTitle);
    expect(tester.widget<Text>(find.text('Forum')).style, T.rowTitleIdle);
  });

  testWidgets("v2: the meta line's host is Plex Mono, the rest the UI face", (tester) async {
    await _pump(tester, _personal());

    final meta = tester.widget<Text>(find.text('notes.example.org · socks5'));
    final span = meta.textSpan! as TextSpan;
    final host = span.children!.first as TextSpan;
    final rest = span.children!.last as TextSpan;
    expect(host.toPlainText(), 'notes.example.org');
    expect(host.style!.fontFamily, T.metaValue.fontFamily);
    expect(host.style!.fontFamily, 'IBMPlexMono');
    expect(rest.text, ' · socks5');
    expect(span.style, T.meta);
    expect(meta.maxLines, isNull, reason: 'the host is never cut short');
  });
}
