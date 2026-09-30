import 'package:container/domain/models/lock_state.dart';
import 'package:container/ui/features/settings/views/auto_lock_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// User's ruling, 2026-09-30: the Auto-lock row opens a sheet of 1, 5 and 15
/// minutes, built like the search engine picker.
void main() {
  testWidgets('lists the three choices under its title, the current one checked', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AutoLockPicker(current: AutoLockPolicy.fiveMinutes, onPick: (_) {})),
    ));

    expect(find.text('Auto-lock'), findsOneWidget);
    for (final label in ['After 1 min', 'After 5 min', 'After 15 min']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    final row = find.ancestor(of: find.text('After 5 min'), matching: find.byType(Row));
    expect(find.descendant(of: row.first, matching: find.byIcon(Icons.check)), findsOneWidget);
  });

  testWidgets('tapping a choice picks it', (tester) async {
    AutoLockPolicy? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoLockPicker(current: AutoLockPolicy.oneMinute, onPick: (p) => picked = p),
      ),
    ));
    await tester.tap(find.text('After 15 min'));
    expect(picked, AutoLockPolicy.fifteenMinutes);
  });
}
