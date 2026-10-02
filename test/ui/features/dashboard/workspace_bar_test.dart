import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/workspace_bar.dart';

import '../../../support/glyph_finders.dart';

void main() {
  Widget harness({required VoidCallback onOverflow}) => MaterialApp(
        home: Scaffold(
          body: WorkspaceBar(
            name: 'Personal',
            trailing: '2 SESSIONS',
            trailingIsBadge: false,
            onTap: () {},
            onOverflow: onOverflow,
          ),
        ),
      );

  testWidgets('the workspace name and trailing text still render',
      (tester) async {
    await tester.pumpWidget(harness(onOverflow: () {}));

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS'), findsOneWidget);
  });

  testWidgets('tapping the overflow icon calls onOverflow', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onOverflow: () => tapped = true));

    expect(tester.getSize(findIconTap('Settings')), const Size(24, 24));
    await tester.tap(findIconTap('Settings'));
    expect(tapped, isTrue);
  });

  testWidgets('the caret and overflow are drawn line icons in the chevron grey', (tester) async {
    await tester.pumpWidget(harness(onOverflow: () {}));

    final caret = tester.widget<AppIcon>(findGlyph(AppGlyph.chevronDown));
    expect(caret.color, C.chevron);
    expect(tester.getSize(findGlyph(AppGlyph.chevronDown)), const Size(14, 14));
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.more)).color, C.chevron);
  });
}
