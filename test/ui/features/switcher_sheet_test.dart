import 'package:container/domain/models/switcher_entry.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/hairline.dart';
import 'package:container/ui/features/container/views/switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glyph_finders.dart';

const _entries = [
  SwitcherEntry(
    siteId: 'st-forum',
    name: 'Forum',
    monogram: 'Fr',
    meta: 'viewing now · socks5',
    live: true,
  ),
  SwitcherEntry(
    siteId: 'st-notes',
    name: 'Notes',
    monogram: 'Nt',
    meta: 'background · 2 min',
    live: false,
  ),
  SwitcherEntry(
    siteId: 'st-webmail',
    name: 'Webmail',
    monogram: 'Wm',
    meta: 'background · 14 min',
    live: false,
  ),
];

/// Spec §5.1's sketch: Forum with two pages, then Notes with none.
const _withPages = [
  SwitcherEntry(
    siteId: 'st-forum',
    name: 'Forum',
    monogram: 'Fr',
    meta: 'viewing now · socks5',
    live: true,
    pages: [
      SwitcherPage(
        pageId: 'pg-rules',
        title: 'Thread: rules',
        host: 'forum.example.com',
        current: true,
      ),
      SwitcherPage(
        pageId: 'pg-members',
        title: 'Members',
        host: 'members.example.com',
        current: false,
      ),
    ],
  ),
  SwitcherEntry(
    siteId: 'st-notes',
    name: 'Notes',
    monogram: 'Nt',
    meta: 'background · 2 min',
    live: false,
  ),
];

final _calls = <String>[];

Future<void> _pump(
  WidgetTester tester, {
  List<SwitcherEntry> entries = _entries,
  VoidCallback? onCloseAllAndWipe,
  VoidCallback? onPanic,
}) {
  _calls.clear();
  // A small phone, as tabs spec §5.1 is checked at.
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SwitcherSheet(
          entries: entries,
          workspaceName: 'Personal',
          onViewContainer: (siteId) => _calls.add('view $siteId'),
          onViewPage: (siteId, pageId) => _calls.add('view $siteId $pageId'),
          onCloseSession: (siteId) => _calls.add('close $siteId'),
          onClosePage: (siteId, pageId) =>
              _calls.add('close $siteId $pageId'),
          onCloseAllAndWipe: onCloseAllAndWipe ?? () {},
          onPanic: onPanic ?? () {},
        ),
      ),
    ),
  ));
}

/// Page rows are `_PageRow`s, private to the sheet.
final _pageRows = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_PageRow');

Finder _close(int index) => findIconTap('Close').at(index);

Color? _colorOf(String text) =>
    (find.text(text).evaluate().single.widget as Text).style?.color;

List<SwitcherEntry> _containers(int count, {required int pages}) => [
      for (var c = 0; c < count; c++)
        SwitcherEntry(
          siteId: 'st-$c',
          name: 'Site $c',
          monogram: 'S$c',
          meta: c == 0 ? 'viewing now · direct' : 'background · $c min',
          live: c == 0,
          pages: [
            for (var p = 0; p < pages; p++)
              SwitcherPage(
                pageId: 'pg-$c-$p',
                title: 'Page $c.$p',
                host: 'host$c.example.com',
                current: p == 0,
              ),
          ],
        ),
    ];

void main() {
  testWidgets('shows the session count, workspace and each row', (tester) async {
    await _pump(tester);

    expect(find.text('3 OPEN SESSIONS'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('viewing now · socks5'), findsOneWidget);
    expect(find.text('background · 2 min'), findsOneWidget);
    expect(find.text('background · 14 min'), findsOneWidget);
    expect(find.text('Close all and wipe'), findsOneWidget);
  });

  testWidgets('the header counts the containers, not their pages',
      (tester) async {
    await _pump(tester, entries: _withPages);

    expect(find.text('2 OPEN SESSIONS'), findsOneWidget);
  });

  testWidgets('an entry with no pages has no page rows', (tester) async {
    await _pump(tester);

    expect(_pageRows, findsNothing);
    expect(findIconTap('Close'), findsNWidgets(3));
  });

  testWidgets('two pages show title then host, in order, under their container',
      (tester) async {
    await _pump(tester, entries: _withPages);

    expect(_pageRows, findsNWidgets(2));
    final order = [
      'viewing now · socks5',
      'Thread: rules',
      'forum.example.com',
      'Members',
      'members.example.com',
      'Notes',
    ].map((text) => tester.getTopLeft(find.text(text)).dy).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i], greaterThan(order[i - 1]), reason: 'row $i');
    }
    // Indented to the container row's text column.
    expect(tester.getTopLeft(find.text('Thread: rules')).dx,
        tester.getTopLeft(find.text('Forum')).dx);
  });

  testWidgets('a hairline falls only between container groups',
      (tester) async {
    await _pump(tester, entries: _withPages);

    final hairlines = find.byType(Hairline);
    expect(hairlines, findsOneWidget);
    // After Forum's last page, above Notes.
    final y = tester.getTopLeft(hairlines).dy;
    expect(y, greaterThan(tester.getBottomLeft(find.text('members.example.com')).dy));
    expect(y, lessThan(tester.getTopLeft(find.text('Notes')).dy));
  });

  testWidgets('tapping a container row views it and closes nothing',
      (tester) async {
    await _pump(tester, entries: _withPages);

    await tester.tap(find.text('background · 2 min'));
    expect(_calls, ['view st-notes']);
  });

  testWidgets('tapping a page row views that page', (tester) async {
    await _pump(tester, entries: _withPages);

    await tester.tap(find.text('members.example.com'));
    expect(_calls, ['view st-forum pg-members']);
  });

  testWidgets("a page's × closes that page only", (tester) async {
    await _pump(tester, entries: _withPages);

    // Forum's ×, then its two pages' ×s, then Notes'.
    await tester.tap(_close(2));
    expect(_calls, ['close st-forum pg-members']);
  });

  testWidgets("a container's × closes that container only", (tester) async {
    await _pump(tester, entries: _withPages);

    await tester.tap(_close(0));
    await tester.tap(_close(3));
    expect(_calls, ['close st-forum', 'close st-notes']);
  });

  testWidgets("the container's last viewed page is primary, the rest muted",
      (tester) async {
    await _pump(tester, entries: _withPages);

    expect(_colorOf('Thread: rules'), C.textPrimary);
    expect(_colorOf('Members'), C.textMuted);
  });

  testWidgets('no text in a page row is jade', (tester) async {
    await _pump(tester, entries: _withPages);

    final texts = find.descendant(of: _pageRows, matching: find.byType(Text));
    expect(texts, findsNWidgets(4)); // a title and a host per page
    for (final element in texts.evaluate()) {
      expect((element.widget as Text).style?.color, isNot(C.jade));
    }
    // The × is a drawn icon since the restyle (Plan 17), and not jade either.
    final closes = find.descendant(of: _pageRows, matching: find.byType(AppIcon));
    expect(closes, findsNWidgets(2)); // a × per page
    for (final element in closes.evaluate()) {
      expect((element.widget as AppIcon).color, isNot(C.jade));
    }
  });

  testWidgets('a 120-character title, host and name do not overflow at 360',
      (tester) async {
    final long = 'a' * 120;
    await _pump(tester, entries: [
      SwitcherEntry(
        siteId: 'st-long',
        name: long,
        monogram: 'Lo',
        meta: 'viewing now · socks5',
        live: true,
        pages: [
          SwitcherPage(
              pageId: 'pg-1', title: long, host: '$long.com', current: true),
          SwitcherPage(
              pageId: 'pg-2', title: long, host: '$long.org', current: false),
        ],
      ),
    ]);

    expect(tester.takeException(), isNull);
    // Each cut to one line with an ellipsis, not wrapped.
    for (final text in find.text(long).evaluate()) {
      expect(tester.getSize(find.byWidget(text.widget)).height, lessThan(26));
    }
    expect(tester.getSize(find.text('$long.com')).height, lessThan(20));
  });

  testWidgets('three containers of six pages each scroll instead of overflowing',
      (tester) async {
    await _pump(tester, entries: _containers(3, pages: 6));

    expect(tester.takeException(), isNull);
    expect(_pageRows, findsNWidgets(18));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(find.text('Page 0.3'), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

    await tester.tap(find.text('Page 2.5'));
    expect(_calls, ['view st-2 pg-2-5']);
  });

  testWidgets('close all and wipe reports a tap with no confirmation',
      (tester) async {
    var tapped = false;
    await _pump(tester, onCloseAllAndWipe: () => tapped = true);

    await tester.tap(find.text('Close all and wipe'));
    expect(tapped, isTrue);
    expect(_calls, isEmpty);
  });

  testWidgets('panic reports a tap with no confirmation', (tester) async {
    var tapped = false;
    await _pump(tester, onPanic: () => tapped = true);

    await tester.tap(findGlyph(AppGlyph.panic));
    expect(tapped, isTrue);
    expect(_calls, isEmpty);
  });

  testWidgets("panic and each row's close are named for screen readers", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.bySemanticsLabel('Panic'), findsOneWidget);
    expect(findIconTap('Close'), findsWidgets);
    expect(tester.getSize(findGlyph(AppGlyph.panic)), const Size(18, 18));
    semantics.dispose();
  });
}
