import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/workspace_bar.dart';

import '../../../support/glyph_finders.dart';

void main() {
  Widget harness() => MaterialApp(
        home: Scaffold(
          body: WorkspaceBar(
            name: 'Personal',
            trailing: '2 SESSIONS',
            trailingIsBadge: false,
            onTap: () {},
          ),
        ),
      );

  testWidgets('the workspace name and trailing text still render', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS'), findsOneWidget);
  });

  testWidgets('Settings is a tab now: the bar has no overflow icon', (tester) async {
    await tester.pumpWidget(harness());

    expect(findIconTap('Settings'), findsNothing);
    expect(findGlyph(AppGlyph.more), findsNothing);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.chevronDown)).color, C.chevron);
  });
}
