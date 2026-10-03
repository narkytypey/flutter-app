import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/workspace_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

const _chips = [
  WorkspaceChip(id: 'w1', name: 'Personal', selected: true),
  WorkspaceChip(id: 'w2', name: 'Work', selected: false),
];

Future<List<String>> _pump(WidgetTester tester, {String? badge}) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: WorkspaceChips(
        chips: _chips,
        onPick: (id) => calls.add('pick $id'),
        onEdit: (id) => calls.add('edit $id'),
        onNew: () => calls.add('new'),
        badge: badge,
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets('one chip per workspace, in order, then the + chip', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    final personal = tester.getCenter(find.text('Personal')).dx;
    final work = tester.getCenter(find.text('Work')).dx;
    final plus = tester.getCenter(findIconTap('New workspace')).dx;
    expect(personal < work && work < plus, isTrue);
    expect(find.bySemanticsLabel('New workspace'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tap picks, a long-press edits, + makes a new one', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Work'));
    await tester.longPress(find.text('Personal'));
    await tester.tap(findIconTap('New workspace'));

    expect(calls, ['pick w2', 'edit w1', 'new']);
  });

  testWidgets('the viewed chip is drawn selected, and nothing is jade', (tester) async {
    await _pump(tester);

    expect(tester.widget<Text>(find.text('Personal')).style!.color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Work')).style!.color, C.tabInactive);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        isNot(contains(C.jade)));
  });

  testWidgets("a wipe-on-exit workspace's badge sits at the row's end (plan D3)", (tester) async {
    await _pump(tester, badge: 'WIPES ON EXIT');

    expect(find.text('WIPES ON EXIT'), findsOneWidget);
    expect(tester.getCenter(find.text('WIPES ON EXIT')).dx,
        greaterThan(tester.getCenter(findIconTap('New workspace')).dx));
  });
}
