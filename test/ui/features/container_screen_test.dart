import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/find_result.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/switcher_entry.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/container/views/address_edit_bar.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
import 'package:container/ui/features/container/views/browser_menu_sheet.dart';
import 'package:container/ui/features/container/views/container_bottom_bar.dart';
import 'package:container/ui/features/container/views/container_screen.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/switcher_sheet.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glyph_finders.dart';

/// Every callback [ContainerScreen] made, by name, in order.
final _calls = <String>[];

/// Every destination [ContainerScreen] asked to open, in order.
final _opened = <Destination>[];

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
const _forum = Site(
  id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
);
const _market = Site(
  id: 'm1', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
);

/// Task 2's suggestions, as the route hands them over.
List<AddressSuggestion> _suggest(String text) => suggestionsFor(
      text: text,
      current: _forum,
      saved: const [_forum, _market],
      workspaces: const [_personal],
      engine: SearchEngine.duckDuckGo,
    );

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

/// Stands in for the native page view: a State that must outlive every change
/// of chrome, as the WebView must — rebuilding it disposes the WebView.
class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFFF4F2EC));
}

NavigationState _nav({
  String url = 'https://forum.example.com/t/9',
  bool canGoBack = false,
  bool canGoForward = false,
  bool loading = false,
  int progress = 0,
}) =>
    NavigationState(
      siteId: 's1',
      pageId: 's1-p1',
      url: url,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      loading: loading,
      progress: progress,
    );

ContainerScreen _screen({
  String host = 'forum.example.com',
  String routeLabel = 'SOCKS5',
  NavigationState? navigation,
  FindResult? findResult,
  bool showSaveBar = false,
  String address = 'https://forum.example.com/t/9',
  List<SwitcherEntry> entries = const [
    SwitcherEntry(
      siteId: 's1',
      name: 'Forum',
      monogram: 'Fr',
      meta: 'viewing now · socks5',
      live: true,
    ),
  ],
}) =>
    ContainerScreen(
      host: host,
      routeLabel: routeLabel,
      live: true,
      navigation: navigation,
      openCount: 3,
      body: const _Page(),
      entries: entries,
      workspaceName: 'Personal',
      siteMonogram: 'Fr',
      siteName: 'Forum',
      siteSubtitle: 'forum.example.com · Personal',
      blockedToday: 312,
      securityLevelMeta: 'STANDARD',
      findResult: findResult,
      showSaveBar: showSaveBar,
      address: address,
      suggest: _suggest,
      onOpen: _opened.add,
      onBack: () => _calls.add('back'),
      onLeave: () => _calls.add('leave'),
      onForward: () => _calls.add('forward'),
      onStop: () => _calls.add('stop'),
      onReload: () => _calls.add('reload'),
      onPanic: () => _calls.add('panic'),
      onSiteDetails: () => _calls.add('site details'),
      onReader: () => _calls.add('reader'),
      onCopyLink: () => _calls.add('copy link'),
      onToday: () => _calls.add('today'),
      onScripts: () => _calls.add('scripts'),
      onWorkspaces: () => _calls.add('workspaces'),
      onSettings: () => _calls.add('settings'),
      onAllSites: () => _calls.add('all sites'),
      onSecurityLevel: () => _calls.add('security level'),
      onNewIdentity: () => _calls.add('new identity'),
      onFind: (query) => _calls.add('find $query'),
      onFindNext: (forward) => _calls.add(forward ? 'next' : 'previous'),
      onClearFind: () => _calls.add('clear find'),
      onSaveAsSite: () => _calls.add('save as a site'),
      onDismissSaveBar: () => _calls.add('dismiss save bar'),
      onViewContainer: (siteId) => _calls.add('view $siteId'),
      onViewPage: (siteId, pageId) => _calls.add('view $siteId $pageId'),
      onCloseSession: (siteId) => _calls.add('close $siteId'),
      onClosePage: (siteId, pageId) => _calls.add('close $siteId $pageId'),
      onCloseAllAndWipe: () => _calls.add('close all and wipe'),
    );

Widget _app(Widget screen) => MaterialApp(home: screen);

/// What the platform sends for a system back gesture.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<void> _openFind(WidgetTester tester) async {
  await tester.tap(_icon('Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find'));
  await tester.pumpAndSettle();
}

/// Taps the pill, which starts editing the address.
Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.text('forum.example.com'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _calls.clear();
    _opened.clear();
  });

  testWidgets('shows the host, the route label and the open count', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('3 OPEN'), findsOneWidget);
  });

  testWidgets('a direct site shows no route label', (tester) async {
    await tester.pumpWidget(_app(_screen(routeLabel: '')));

    expect(find.text('SOCKS5'), findsNothing);
  });

  testWidgets("the pill ends in the shield, which opens the site's details; panic sits beside it", (tester) async {
    await tester.pumpWidget(_app(_screen()));

    expect(tester.getCenter(_icon('Site details')).dx,
        greaterThan(tester.getCenter(find.text('SOCKS5')).dx));
    expect(tester.getCenter(_icon('Panic')).dx,
        greaterThan(tester.getCenter(_icon('Site details')).dx));
    await tester.tap(_icon('Site details'));
    await tester.tap(_icon('Panic'));

    expect(_calls, ['site details', 'panic']);
    // 2b's ‹ and ⟳ have left the top bar.
    expect(find.text('‹'), findsNothing);
    expect(find.text('⟳'), findsNothing);
  });

  testWidgets('stop sits before the shield only while the page loads', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav())));
    expect(_icon('Stop'), findsNothing);

    await tester.pumpWidget(_app(_screen(navigation: _nav(loading: true, progress: 30))));
    expect(tester.getCenter(_icon('Stop')).dx,
        lessThan(tester.getCenter(_icon('Site details')).dx));
    await tester.tap(_icon('Stop'));

    expect(_calls, ['stop']);
  });

  testWidgets('the load line lies over the top of the page, only while it loads', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(loading: true, progress: 50))));

    final line = tester.getRect(find.byKey(const Key('load-line')));
    final page = tester.getRect(find.byType(_Page));
    expect(line.top, page.top);
    expect(line.width, page.width / 2);

    await tester.pumpWidget(_app(_screen(navigation: _nav(progress: 100))));
    expect(find.byKey(const Key('load-line')), findsNothing);
  });

  testWidgets('back and forward follow the page history', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await tester.tap(_icon('Back'), warnIfMissed: false);
    await tester.tap(_icon('Forward'), warnIfMissed: false);
    expect(_calls, isEmpty);

    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true, canGoForward: true))));
    await tester.tap(_icon('Back'));
    await tester.tap(_icon('Forward'));

    expect(_calls, ['back', 'forward']);
  });

  testWidgets('tapping the open-count pill opens the switcher sheet', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    await tester.tap(find.text('3 OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('1 OPEN SESSIONS'), findsOneWidget);
    expect(find.text('viewing now · socks5'), findsOneWidget);
  });

  testWidgets('the switcher closes itself before each view or close it reports', (tester) async {
    const entries = [
      SwitcherEntry(
        siteId: 's1',
        name: 'Forum',
        monogram: 'Fr',
        meta: 'viewing now · socks5',
        live: true,
        pages: [
          SwitcherPage(
              pageId: 'p1', title: 'Thread: rules',
              host: 'forum.example.com', current: true),
          SwitcherPage(
              pageId: 'p2', title: 'Members',
              host: 'forum.example.com', current: false),
        ],
      ),
    ];
    await tester.pumpWidget(_app(_screen(entries: entries)));

    final taps = <(Finder Function(), String)>[
      (
        () => find.descendant(
            of: find.byType(SwitcherSheet), matching: find.text('Forum')),
        'view s1'
      ),
      (() => find.text('Members'), 'view s1 p2'),
      (
        () => find.descendant(
            of: find.byType(SwitcherSheet), matching: findIconTap('Close')).at(1),
        'close s1 p1'
      ),
      (
        () => find.descendant(
            of: find.byType(SwitcherSheet), matching: findIconTap('Close')).first,
        'close s1'
      ),
    ];
    for (final (target, call) in taps) {
      await tester.tap(find.text('3 OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(target());
      await tester.pumpAndSettle();
      expect(find.byType(SwitcherSheet), findsNothing, reason: call);
      expect(_calls.last, call);
    }
  });

  testWidgets('the ☰ menu names this site, and closes itself before each action it reports', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('312 BLOCKED'), findsOneWidget);
    Navigator.of(tester.element(find.byType(BrowserMenuSheet))).pop();
    await tester.pumpAndSettle();

    const actions = [
      ('Reload', 'reload'),
      ('Reader', 'reader'),
      ('Copy link', 'copy link'),
      ('Security level', 'security level'),
      ('New identity', 'new identity'),
      ('Today', 'today'),
      ('Scripts and filters', 'scripts'),
      ('Workspaces', 'workspaces'),
      ('Settings', 'settings'),
      ('All sites', 'all sites'),
    ];
    for (final (label, call) in actions) {
      await tester.tap(_icon('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserMenuSheet), findsNothing, reason: label);
      expect(_calls.last, call);
    }
    expect(_calls, hasLength(actions.length));
  });

  testWidgets('Find puts the find bar in place of the top bar; typing, stepping and closing report', (tester) async {
    await tester.pumpWidget(_app(_screen(
      findResult: const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 2, matchCount: 5),
    )));
    await _openFind(tester);

    expect(find.byType(ContainerTopBar), findsNothing);
    expect(find.text('Find in page'), findsOneWidget);
    expect(_icon('Panic'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    expect(find.text('3/5'), findsOneWidget);
    await tester.tap(_icon('Previous match'));
    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();

    expect(_calls, ['find fox', 'previous', 'next', 'clear find']);
    expect(find.byType(FindBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);
  });

  // Tabs spec §5.3: where back goes with no history is the route's to decide,
  // so the screen never pops by itself.
  testWidgets('system back goes back in the page while it can, then reports leaving', (tester) async {
    final navigation = ValueNotifier<NavigationState?>(_nav(canGoBack: true));
    addTearDown(navigation.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('home')));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ValueListenableBuilder<NavigationState?>(
        valueListenable: navigation,
        builder: (_, value, __) => _screen(navigation: value),
      ),
    ));
    await tester.pumpAndSettle();

    await _systemBack(tester);
    expect(_calls, ['back']);
    expect(find.byType(ContainerScreen), findsOneWidget);

    navigation.value = _nav();
    await tester.pumpAndSettle();
    await _systemBack(tester);

    expect(_calls, ['back', 'leave']);
    expect(find.byType(ContainerScreen), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  // Review Focus 2.
  testWidgets('system back while finding closes find, and goes nowhere', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true))));
    await _openFind(tester);

    await _systemBack(tester);

    expect(find.byType(FindBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);
    expect(_calls, ['clear find']);
  });

  testWidgets('the save bar shows only when asked, directly above the bottom bar', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    expect(find.byType(ThrowawaySaveBar), findsNothing);

    await tester.pumpWidget(_app(_screen(showSaveBar: true)));
    expect(tester.getRect(find.byType(ThrowawaySaveBar)).bottom,
        tester.getRect(find.byType(ContainerBottomBar)).top);
    await tester.tap(find.text('Save as a site'));
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));

    expect(_calls, ['save as a site', 'dismiss save bar']);
  });

  // Review Focus 1.
  testWidgets('the page view is never rebuilt as the chrome changes', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    final page = tester.state(find.byType(_Page));

    await tester.pumpWidget(_app(_screen(
      navigation: _nav(loading: true, progress: 30, canGoBack: true),
    )));
    await tester.pumpWidget(_app(_screen(
      navigation: _nav(loading: true, progress: 30, canGoBack: true),
      showSaveBar: true,
    )));
    await _openFind(tester);
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(_screen()));

    expect(tester.state(find.byType(_Page)), same(page));
  });

  // Review Focus 5.
  testWidgets('at 360 wide a long host, a route, a load and the save bar all fit', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_screen(
      host: 'a-rather-long-subdomain.forum.example.com',
      navigation: _nav(loading: true, progress: 40, canGoBack: true, canGoForward: true),
      showSaveBar: true,
    )));
    expect(tester.takeException(), isNull);

    await _openFind(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the pill starts editing on the page address, selected, with panic beside it', (tester) async {
    const address = 'https://forum.example.com/t/9';
    await tester.pumpWidget(_app(_screen(address: address)));

    await _edit(tester);

    expect(find.byType(ContainerTopBar), findsNothing);
    expect(find.byType(AddressEditBar), findsOneWidget);
    expect(_icon('Panic'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, address);
    expect(field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: address.length));
    // The list covers the page and the bottom bar.
    final list = tester.getRect(find.byType(AddressSuggestions));
    expect(list.top, tester.getRect(find.byType(_Page)).top);
    expect(list.bottom, tester.getRect(find.byType(ContainerBottomBar)).bottom);
    expect(_calls, isEmpty);
  });

  testWidgets('typing lists what the text would open; tapping a row leaves editing and opens it', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _edit(tester);

    await tester.enterText(find.byType(TextField), 'mark');
    await tester.pump();
    expect(find.text('SAVED SITES'), findsOneWidget);
    expect(find.text('Search DuckDuckGo for “mark”'), findsOneWidget);
    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();

    expect(find.byType(AddressEditBar), findsNothing);
    expect(_opened.single, isA<SavedSiteContainer>());
    expect(_opened.single.url.toString(), 'https://market.example.com');
  });

  testWidgets('the keyboard opens the address row, or the search row when there is none', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'news.example.org');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'privacy tools');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    // Nothing typed: nothing to open, and editing ends.
    await _edit(tester);
    await tester.tap(_icon('Clear'));
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(_opened.map((destination) => destination.url.toString()),
        ['https://news.example.org', 'https://duckduckgo.com/?q=privacy+tools']);
    expect(find.byType(AddressEditBar), findsNothing);
  });

  // Review Focus 2.
  testWidgets('back, or a tap outside the list, leaves editing without going anywhere', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true))));

    await _edit(tester);
    await _systemBack(tester);
    expect(find.byType(AddressEditBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);

    await _edit(tester);
    await tester.tapAt(
        tester.getBottomLeft(find.byType(AddressSuggestions)) + const Offset(40, -20));
    await tester.pumpAndSettle();
    expect(find.byType(AddressEditBar), findsNothing);

    expect(_calls, isEmpty);
    expect(_opened, isEmpty);
  });

  // Review Focus 1.
  testWidgets('the page view survives editing', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    final page = tester.state(find.byType(_Page));

    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'news');
    await tester.pump();
    await _systemBack(tester);

    expect(tester.state(find.byType(_Page)), same(page));
  });

  // Review Focus 5.
  testWidgets('at 360 wide, editing a long address fits', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_screen(
      address: 'https://a-rather-long-subdomain.forum.example.com/threads/12345?page=2',
    )));

    await _edit(tester);
    await tester.enterText(
        find.byType(TextField), 'market.example.com/a/very/long/path/that/keeps/going');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
