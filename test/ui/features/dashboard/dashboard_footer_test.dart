import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/dashboard_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

void main() {
  testWidgets('search is a drawn icon, named for screen readers, and reports a tap', (tester) async {
    final semantics = tester.ensureSemantics();
    var searches = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: DashboardFooter(onAddSite: () {}, onSearch: () => searches++),
        ),
      ),
    ));

    expect(find.text('+ Add site'), findsOneWidget);
    expect(tester.getSize(findGlyph(AppGlyph.search)), const Size(20, 20));
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.search)).color, C.icon);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);

    await tester.tap(findGlyph(AppGlyph.search));
    expect(searches, 1);
    semantics.dispose();
  });
}
