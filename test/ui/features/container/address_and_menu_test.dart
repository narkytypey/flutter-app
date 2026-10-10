import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/container/views/address_edit_bar.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
import 'package:container/ui/features/container/views/browser_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

const _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
);
const _market = Site(
  id: 'market', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
);

/// What Task 2 suggests for [text], typed in the SOCKS5 forum's container.
List<AddressSuggestion> _rows(String text) => suggestionsFor(
      text: text,
      current: _forum,
      saved: const [_forum, _market],
      workspaces: const [_personal],
      engine: SearchEngine.duckDuckGo,
    );

Widget _bar(
  TextEditingController controller, {
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) =>
    AddressEditBar(
      controller: controller,
      onChanged: onChanged ?? (_) {},
      onSubmitted: onSubmitted ?? (_) {},
    );

Widget _menu(
  List<String> calls, {
  String subtitle = 'forum.example.com · Personal',
  bool canGoBack = true,
  bool canGoForward = true,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BrowserMenuSheet(
            monogram: 'Fr',
            name: 'Forum',
            subtitle: subtitle,
            blockedToday: 312,
            securityLevelMeta: 'STANDARD',
            onSecurityLevel: () => calls.add('security level'),
            onNewIdentity: () => calls.add('new identity'),
            onBack: canGoBack ? () => calls.add('back') : null,
            onForward: canGoForward ? () => calls.add('forward') : null,
            onReload: () => calls.add('reload'),
            onFind: () => calls.add('find'),
            onReader: () => calls.add('reader'),
            onCopyLink: () => calls.add('copy link'),
            onToday: () => calls.add('today'),
            onScripts: () => calls.add('scripts'),
            onWorkspaces: () => calls.add('workspaces'),
            onSettings: () => calls.add('settings'),
            onAllSites: () => calls.add('all sites'),
          ),
        ),
      ),
    );

const _menuLabels = [
  'Back', 'Forward', 'Reload', 'Find', 'Reader', 'Copy link',
  'Today', 'Scripts and filters', 'Workspaces', 'Settings', 'All sites',
];

void main() {
  testWidgets('the address field is raised, hinted, and asks the keyboard to learn nothing', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [_bar(controller)]))));

    expect(find.text('Search or type an address'), findsOneWidget);
    final pill = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color, C.surface);
    expect((decoration.border! as Border).top.color, C.edge);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorColor, C.textPrimary);
    expect(field.keyboardType, TextInputType.url);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    // User's ruling, 2026-10-10: panic is started only by flipping face down.
    expect(_icon('Panic'), findsNothing);
  });

  testWidgets('typing, the keyboard action and clearing each report', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          _bar(
            controller,
            onChanged: (text) => calls.add('changed $text'),
            onSubmitted: (text) => calls.add('submitted $text'),
          ),
        ]),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'news.example.org');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    await tester.tap(_icon('Clear'));
    await tester.pump();

    expect(calls, [
      'changed news.example.org',
      'submitted news.example.org',
      'changed ',
    ]);
    expect(controller.text, isEmpty);
  });

  testWidgets('rows sit under their sections, each with where it opens, above the footer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(
          suggestions: _rows('market.example.com'),
          onPick: (_) {},
          onDismiss: () {},
        ),
      ),
    ));

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('SAVED SITES'), lessThan(top('Marketplace')));
    expect(top('Marketplace'), lessThan(top('ADDRESS')));
    expect(top('ADDRESS'), lessThan(top('SEARCH')));
    expect(top('SEARCH'), lessThan(top('Nothing is fetched while you type.')));

    expect(find.text('Mk'), findsOneWidget);
    expect(find.text('market.example.com · Personal'), findsOneWidget);
    expect(find.text('not saved'), findsOneWidget);
    expect(find.text('Search DuckDuckGo for “market.example.com”'), findsOneWidget);
    // The saved row and the address row both open the market's container;
    // the search opens a throwaway on the forum's SOCKS5 route.
    expect(find.text('ITS OWN CONTAINER'), findsNWidgets(2));
    expect(find.text('THROWAWAY · SOCKS5'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.glyph == AppGlyph.globe), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.glyph == AppGlyph.search), findsOneWidget);
  });

  testWidgets('tapping a row picks it; tapping anywhere else dismisses', (tester) async {
    final picked = <AddressSuggestion>[];
    var dismissed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(
          suggestions: _rows('mark'),
          onPick: picked.add,
          onDismiss: () => dismissed++,
        ),
      ),
    ));

    await tester.tap(find.text('Marketplace'));
    expect(picked.single.destination, isA<SavedSiteContainer>());
    expect(dismissed, 0);

    await tester.tapAt(
        tester.getBottomLeft(find.byType(AddressSuggestions)) + const Offset(40, -40));
    expect(dismissed, 1);
    expect(picked, hasLength(1));
  });

  testWidgets('with nothing typed, only the footer shows, in dim mono', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(suggestions: _rows('   '), onPick: (_) {}, onDismiss: () {}),
      ),
    ));

    expect(find.text('SEARCH'), findsNothing);
    final footer = tester.widget<Text>(find.text('Nothing is fetched while you type.'));
    expect(footer.style!.fontFamily, 'IBMPlexMono');
    expect(footer.style!.color, C.textFaint);
  });

  testWidgets('the menu shows this site, six quick actions in a row, then five rows', (tester) async {
    await tester.pumpWidget(_menu([]));

    expect(find.text('Fr'), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    final subtitle = tester.widget<Text>(find.text('forum.example.com · Personal'));
    expect(subtitle.style!.fontFamily, 'IBMPlexMono');
    for (final label in _menuLabels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('312 BLOCKED'), findsOneWidget);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    double left(String text) => tester.getTopLeft(find.text(text)).dx;
    // Back and forward lead the quick actions (user's ruling, 2026-10-10).
    expect(top('Back'), top('Copy link'));
    expect(left('Back'), lessThan(left('Forward')));
    expect(left('Forward'), lessThan(left('Reload')));
    expect(top('Reload'), top('Copy link'));
    expect(top('Copy link'), lessThan(top('Today')));
    expect(top('Today'), lessThan(top('Scripts and filters')));
    expect(top('Settings'), lessThan(top('All sites')));
  });

  testWidgets('every quick action and row reports its own tap', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_menu(calls));

    for (final label in _menuLabels) {
      await tester.tap(find.text(label));
    }

    expect(calls, [
      'back', 'forward', 'reload', 'find', 'reader', 'copy link',
      'today', 'scripts', 'workspaces', 'settings', 'all sites',
    ]);
  });

  testWidgets("Security level and New identity come first, with the level's meta",
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrowserMenuSheet(
      monogram: 'Fr', name: 'Forum', subtitle: 'forum.example.com · Personal',
      blockedToday: 3, securityLevelMeta: 'SAFER',
      onSecurityLevel: () => taps.add('level'), onNewIdentity: () => taps.add('identity'),
      onBack: null, onForward: null, onReload: () {}, onFind: () {}, onReader: () {}, onCopyLink: () {}, onToday: () {},
      onScripts: () {}, onWorkspaces: () {}, onSettings: () {}, onAllSites: () {},
    ))));
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('SAFER'), findsOneWidget);
    final order = ['Security level', 'New identity', 'Today', 'Scripts and filters',
        'Workspaces', 'Settings', 'All sites'];
    for (var i = 1; i < order.length; i++) {
      expect(tester.getTopLeft(find.text(order[i - 1])).dy,
          lessThan(tester.getTopLeft(find.text(order[i])).dy), reason: order[i]);
    }
    await tester.tap(find.text('Security level'));
    await tester.tap(find.text('New identity'));
    expect(taps, ['level', 'identity']);
  });

  testWidgets('back and forward are dimmed and inert with no history that way', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_menu(calls, canGoBack: false));

    await tester.tap(find.text('Back'), warnIfMissed: false);
    await tester.tap(find.text('Forward'));

    expect(calls, ['forward']);
    // The tile's own icon: AppGlyph.forward is also every row's chevron.
    AppIcon tileIcon(String label) => tester.widget<AppIcon>(find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first,
        matching: find.byType(AppIcon)));
    expect(tileIcon('Back').glyph, AppGlyph.back);
    expect(tileIcon('Back').color, C.textFaint);
    expect(tileIcon('Forward').glyph, AppGlyph.forward);
    expect(tileIcon('Forward').color, isNot(C.textFaint));
  });

  // Review Focus 5.
  testWidgets('at 360 wide the address bar, its suggestions and the menu all fit', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(
        text: 'market.example.com/a/rather/long/path?with=a&query=string');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          _bar(controller),
          Expanded(
            child: AddressSuggestions(
              suggestions: _rows(controller.text),
              onPick: (_) {},
              onDismiss: () {},
            ),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_menu(
      [],
      subtitle: 'a-rather-long-subdomain.forum.example.com · A long workspace name',
    ));
    expect(tester.takeException(), isNull);
  });
}
