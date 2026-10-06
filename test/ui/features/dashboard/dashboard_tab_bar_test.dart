import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

Future<List<DashboardTab>> _pump(WidgetTester tester, DashboardTab current) async {
  final picked = <DashboardTab>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DashboardTabBar(current: current, onSelect: picked.add),
      ),
    ),
  ));
  return picked;
}

void main() {
  testWidgets('three tabs, each a line icon over its label, in order', (tester) async {
    await _pump(tester, DashboardTab.sites);

    final xs = [
      for (final label in ['Sites', 'Today', 'Settings']) tester.getCenter(find.text(label)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    for (final glyph in [AppGlyph.sitesFilled, AppGlyph.today, AppGlyph.settings]) {
      expect(tester.getSize(findGlyph(glyph)), const Size(20, 20));
    }
  });

  testWidgets('the viewed tab is primary, the others muted, and nothing is jade', (tester) async {
    await _pump(tester, DashboardTab.today);

    expect(tester.widget<Text>(find.text('Today')).style!.color, C.textPrimary);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.todayFilled)).color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Sites')).style!.color, C.textMuted);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.settings)).color, C.textMuted);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        isNot(contains(C.jade)));
  });

  testWidgets('a tap anywhere on a tab reports it', (tester) async {
    final picked = await _pump(tester, DashboardTab.sites);

    await tester.tap(find.text('Settings'));
    await tester.tap(findGlyph(AppGlyph.today));
    expect(picked, [DashboardTab.settings, DashboardTab.today]);
  });

  // Restyle v2 §5 (Plan 21 Task 1).
  testWidgets('v2: the viewed tab shows its filled glyph, labels are 13 sp, no jade paint',
      (tester) async {
    await _pump(tester, DashboardTab.sites);

    expect(findGlyph(AppGlyph.sitesFilled), findsOneWidget);
    expect(findGlyph(AppGlyph.sites), findsNothing);
    expect(findGlyph(AppGlyph.today), findsOneWidget);
    for (final label in ['Sites', 'Today', 'Settings']) {
      expect(tester.widget<Text>(find.text(label)).style!.fontSize, 13);
    }
    expect(tester.widget<Text>(find.text('Sites')).style!.fontWeight, FontWeight.w600);
    final bar = find.byType(DashboardTabBar);
    final decorations = [
      for (final box in tester.widgetList<Container>(
          find.descendant(of: bar, matching: find.byType(Container))))
        if (box.decoration is BoxDecoration) box.decoration! as BoxDecoration,
      for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: bar, matching: find.byType(DecoratedBox))))
        if (box.decoration is BoxDecoration) box.decoration as BoxDecoration,
    ];
    for (final d in decorations) {
      expect(d.color, isNot(C.jade));
      final border = d.border;
      if (border is Border) expect(border.top.color, isNot(C.jade));
    }
    for (final icon in tester.widgetList<AppIcon>(find.byType(AppIcon))) {
      expect(icon.color, isNot(C.jade));
    }
  });
}
