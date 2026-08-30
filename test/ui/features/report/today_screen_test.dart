import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/ui/features/report/views/today_screen.dart';

void main() {
  const tally = BlockedTally(
    categories: [
      CategoryTally(category: BlockedCategory.trackers, count: 198),
      CategoryTally(category: BlockedCategory.ads, count: 88),
      CategoryTally(category: BlockedCategory.fingerprinting, count: 24),
      CategoryTally(category: BlockedCategory.permissionAsks, count: 2),
    ],
    sites: [
      SiteTally(monogram: 'Fr', name: 'Forum', count: 164),
      SiteTally(monogram: 'Mk', name: 'Marketplace', count: 97),
      SiteTally(monogram: 'Rd', name: 'Reader', count: 39),
      SiteTally(monogram: 'Wm', name: 'Webmail', count: 12),
    ],
  );

  testWidgets('renders the spec copy and numbers verbatim', (tester) async {
    // The default 800x600 test surface is shorter than four category rows
    // plus four site rows plus the total block, so the last few rows never
    // enter the sliver list's build range and find.text can't see them.
    // Widen the surface rather than scroll, since every assertion below
    // needs simultaneous visibility.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;

    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      home: TodayScreen(tally: tally, onBack: () => backs++),
    ));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('requests blocked across 4 sites'), findsOneWidget);

    expect(find.text('Trackers'), findsOneWidget);
    expect(find.text('198'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Fingerprinting'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Permission asks'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    expect(find.text('BY SITE'), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('164'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Webmail'), findsOneWidget);

    expect(
      find.text('Counts are kept in memory only and reset when the app closes.'),
      findsOneWidget,
    );

    await tester.tap(find.text('‹'));
    expect(backs, 1);
  });
}
