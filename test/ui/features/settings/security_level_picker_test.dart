import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/features/settings/views/security_level_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget picker) => MaterialApp(home: Scaffold(body: picker));

Finder _checkIn(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.check),
    );

void main() {
  testWidgets('the vault picker lists the three levels with their lines, the current checked',
      (tester) async {
    await tester.pumpWidget(_host(
        SecurityLevelPicker.vault(current: SecurityLevel.safer, onPick: (_) {})));

    expect(find.text('Security level'), findsOneWidget);
    for (final level in SecurityLevel.values) {
      expect(find.text(level.label), findsOneWidget);
      expect(find.text(level.description), findsOneWidget);
    }
    expect(find.text('Default'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(_checkIn('Safer'), findsOneWidget);
  });

  testWidgets('the site picker starts with Default, checked while the site follows it',
      (tester) async {
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: null, vaultDefault: SecurityLevel.standard, onPick: (_) {})));

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Standard · set in Settings'), findsOneWidget);
    expect(_checkIn('Default'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets("a site's own level is checked instead of Default", (tester) async {
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: SecurityLevel.safest, vaultDefault: SecurityLevel.safer, onPick: (_) {})));

    expect(find.text('Safer · set in Settings'), findsOneWidget);
    expect(_checkIn('Safest'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping reports the level, and Default reports null', (tester) async {
    final picked = <SecurityLevel?>[];
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: SecurityLevel.safest, vaultDefault: SecurityLevel.standard, onPick: picked.add)));

    await tester.tap(find.text('Safer'));
    await tester.tap(find.text('Default'));
    expect(picked, [SecurityLevel.safer, null]);
  });
}
