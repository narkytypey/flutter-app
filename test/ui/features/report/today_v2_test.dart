import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/typography.dart';
import 'package:container/ui/core/widgets/group.dart';
import 'package:container/ui/features/report/views/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';
import '../settings/settings_v2_test.dart' show paintedColours;

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
    ],
  );

  Future<void> pump(WidgetTester tester) {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    return tester.pumpWidget(MaterialApp(home: TodayScreen(tally: tally, onBack: () {})));
  }

  TextStyle styleOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!;

  testWidgets('v2: the total is T.display', (tester) async {
    await pump(tester);
    expect(styleOf(tester, '312'), T.display);
  });

  testWidgets('v2: nothing on 5c is jade; bars are text-2 on group tracks', (tester) async {
    await pump(tester);
    final colours = paintedColours(tester, find.byType(TodayScreen));
    expect(colours, isNot(contains(C.jade)));
    expect(colours, isNot(contains(C.warning)));
    expect(colours.where((c) => c == C.textMuted), isNotEmpty);
    expect(colours, contains(C.surface));
  });

  testWidgets('v2: counts are Mono', (tester) async {
    await pump(tester);
    for (final count in ['198', '88', '24', '2', '164', '97']) {
      expect(styleOf(tester, count).fontFamily, 'IBMPlexMono', reason: count);
    }
  });

  testWidgets('v2: sites sit in one Group; BY SITE is a section label', (tester) async {
    await pump(tester);
    expect(find.ancestor(of: find.text('Forum'), matching: find.byType(Group)), findsOneWidget);
    expect(styleOf(tester, 'BY SITE'), T.sectionLabel);
  });

  testWidgets('v2: Back is a 48 dp target', (tester) async {
    await pump(tester);
    expect(tester.getSize(findIconTap('Back')), const Size(48, 48));
  });
}
