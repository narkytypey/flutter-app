import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:container/ui/features/dashboard/views/sites_tab.dart';
import 'package:container/ui/features/report/views/today_screen.dart';
import 'package:container/ui/features/settings/views/default_route_screen.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

/// The dashboard shell's own back handler: the first `PopScope` under it.
PopScope _dashboardScope(WidgetTester tester) => tester.widget<PopScope>(find
    .descendant(
        of: find.byType(DashboardScreen), matching: find.byWidgetPredicate((w) => w is PopScope))
    .first);

void main() {
  testWidgets('the dashboard opens on Sites, under the three tabs', (tester) async {
    await pumpDashboard(tester);

    expect(find.byType(SitesTab), findsOneWidget);
    for (final label in ['Sites', 'Today', 'Settings']) {
      expect(find.descendant(of: find.byType(DashboardTabBar), matching: find.text(label)),
          findsOneWidget);
    }
  });

  testWidgets('the tab labels are not drawn in the no-Material error style', (tester) async {
    await pumpDashboard(tester);

    // Outside a Material, text inherits MaterialApp's error style: a yellow
    // double underline (seen on the emulator 2026-10-05).
    for (final label in ['Sites', 'Today', 'Settings']) {
      final text = tester.widget<RichText>(find.descendant(
          of: find.byType(DashboardTabBar),
          matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == label)));
      expect(text.text.style?.decoration, isNot(TextDecoration.underline), reason: label);
    }
  });

  testWidgets('each tab shows its screen, with no back icon', (tester) async {
    await pumpDashboard(tester);

    await tapTab(tester, 'Today');
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);

    await tapTab(tester, 'Settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);
    expect(find.text('Default route'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);

    await tapTab(tester, 'Sites');
    expect(find.byType(SitesTab), findsOneWidget);
  });

  testWidgets('system back on Today or Settings shows Sites', (tester) async {
    await pumpDashboard(tester);

    await tapTab(tester, 'Today');
    await systemBack(tester);
    expect(find.byType(SitesTab), findsOneWidget);

    await tapTab(tester, 'Settings');
    await systemBack(tester);
    expect(find.byType(SitesTab), findsOneWidget);
  });

  testWidgets('on Sites, back is left to the system, as before', (tester) async {
    await pumpDashboard(tester);
    expect(_dashboardScope(tester).canPop, isTrue);

    await tapTab(tester, 'Today');
    expect(_dashboardScope(tester).canPop, isFalse);
  });

  testWidgets('a screen pushed from a tab covers the tab bar', (tester) async {
    await pumpDashboard(tester);
    await tapTab(tester, 'Settings');

    await tester.tap(find.text('Default route'));
    await tester.pumpAndSettle();

    expect(find.byType(DefaultRouteScreen), findsOneWidget);
    expect(find.byType(DashboardTabBar), findsNothing);
  });

  testWidgets('the bar steps aside while the keyboard is up (plan D4)', (tester) async {
    await pumpDashboard(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byType(DashboardTabBar), findsNothing);
    expect(find.byType(SitesTab), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(find.byType(DashboardTabBar), findsOneWidget);
  });
}
