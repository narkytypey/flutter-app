import 'package:container/ui/core/icons.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  void Function(String)? onCloseSession,
  VoidCallback? onCloseAllAndWipe,
  VoidCallback? onPanic,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SwitcherSheet(
        entries: _entries,
        workspaceName: 'Personal',
        onCloseSession: onCloseSession ?? (_) {},
        onCloseAllAndWipe: onCloseAllAndWipe ?? () {},
        onPanic: onPanic ?? () {},
      ),
    ),
  ));
}

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

  testWidgets('closing a row reports its site id', (tester) async {
    final closed = <String>[];
    await _pump(tester, onCloseSession: closed.add);

    await tester.tap(findIconTap('Close').first);
    expect(closed, ['st-forum']);
  });

  testWidgets('close all and wipe reports a tap with no confirmation',
      (tester) async {
    var tapped = false;
    await _pump(tester, onCloseAllAndWipe: () => tapped = true);

    await tester.tap(find.text('Close all and wipe'));
    expect(tapped, isTrue);
  });

  testWidgets('panic reports a tap with no confirmation', (tester) async {
    var tapped = false;
    await _pump(tester, onPanic: () => tapped = true);

    await tester.tap(findGlyph(AppGlyph.panic));
    expect(tapped, isTrue);
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
