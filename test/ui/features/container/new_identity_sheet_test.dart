import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/container/views/new_identity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> ask(WidgetTester tester, Future<void> Function() act) async {
    bool? answer;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async => answer = await confirmNewIdentity(context),
        child: const Text('open'),
      ),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('the approved copy, and no jade', (tester) async {
    await ask(tester, () async {
      expect(find.text('New identity for this site?'), findsOneWidget);
      expect(find.text(
          'Its logins, storage and downloads are destroyed, and it starts over at its first page.'),
          findsOneWidget);
      expect(find.text('New identity'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == C.jade),
          isEmpty);
    });
  });

  testWidgets('New identity answers true', (tester) async {
    expect(await ask(tester, () => tester.tap(find.text('New identity'))), isTrue);
  });

  testWidgets('Cancel, a tap outside and back answer false', (tester) async {
    expect(await ask(tester, () => tester.tap(find.text('Cancel'))), isFalse);
    expect(await ask(tester, () => tester.tapAt(const Offset(10, 10))), isFalse);
    expect(await ask(tester, () async {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.maybePop();
    }), isFalse);
  });
}
