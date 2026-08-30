import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/ui/features/in_page/views/permission_request_sheet.dart';

void main() {
  Widget host({required ValueChanged<PermissionDecision> onDecision}) {
    return MaterialApp(
      home: Scaffold(
        body: PermissionRequestSheet(
          host: 'meet.example.com',
          kind: PermissionKind.microphone,
          onDecision: onDecision,
        ),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host(onDecision: (_) {}));

    expect(find.text('meet.example.com wants your microphone'), findsOneWidget);
    expect(
      find.text(
        'It is blocked right now. Allowing it applies to this site only, '
        'inside this container.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow once'), findsOneWidget);
    expect(find.text('Allow while this site is open'), findsOneWidget);
    expect(find.text('Keep blocked'), findsOneWidget);
  });

  testWidgets('each action reports its own decision', (tester) async {
    final seen = <PermissionDecision>[];
    await tester.pumpWidget(host(onDecision: seen.add));

    await tester.tap(find.text('Allow once'));
    await tester.tap(find.text('Allow while this site is open'));
    await tester.tap(find.text('Keep blocked'));

    expect(seen, [
      PermissionDecision.allowOnce,
      PermissionDecision.allowWhileOpen,
      PermissionDecision.keepBlocked,
    ]);
  });

  testWidgets('offers no way to remember the grant permanently',
      (tester) async {
    await tester.pumpWidget(host(onDecision: (_) {}));

    expect(find.text('Always allow'), findsNothing);
    expect(find.text('Remember'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
