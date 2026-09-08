import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/features/settings/views/decoy_resync_pin_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {int filled = 0, bool error = false}) {
    return tester.pumpWidget(MaterialApp(
      home: DecoyResyncPinScreen(filled: filled, error: error, onKey: (_) {}),
    ));
  }

  testWidgets('prompts for the decoy PIN and never mentions vaults',
      (tester) async {
    await pump(tester);

    expect(find.text('Enter the decoy PIN'), findsOneWidget);
    expect(find.textContaining('decoy vault'), findsNothing,
        reason: 'the same instinct LockBody follows: give no more away in '
            'copy than necessary');
  });

  testWidgets('shows six empty dots at rest', (tester) async {
    await pump(tester);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 0);
    expect(dots.error, isFalse);
  });

  testWidgets('shows filled dots as digits are entered', (tester) async {
    await pump(tester, filled: 3);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 3);
  });

  testWidgets('shows the error state and a wrong-PIN message', (tester) async {
    await pump(tester, error: true);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.error, isTrue);
    expect(find.text('Wrong PIN'), findsOneWidget);
  });

  testWidgets('forwards keypad taps', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: DecoyResyncPinScreen(filled: 0, error: false, onKey: pressed.add),
    ));

    await tester.tap(find.text('5'));

    expect(pressed, ['5']);
  });
}
