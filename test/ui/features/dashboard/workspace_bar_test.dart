import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/dashboard/views/workspace_bar.dart';

void main() {
  Widget harness({required VoidCallback onOverflow}) => MaterialApp(
        home: Scaffold(
          body: WorkspaceBar(
            name: 'Personal',
            trailing: '2 SESSIONS · 0 LEAKS',
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
    expect(find.text('2 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('tapping the overflow icon calls onOverflow', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onOverflow: () => tapped = true));

    await tester.tap(find.text('⋯'));
    expect(tapped, isTrue);
  });
}
