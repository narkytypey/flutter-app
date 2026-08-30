import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/core/widgets/pin_keypad.dart';

void main() {
  testWidgets('the dots fill left to right', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: PinDots(filled: 3)))));

    final dots = tester.widgetList<Container>(find.byType(Container)).toList();
    expect(dots.length, 6);
    expect((dots[0].decoration! as BoxDecoration).color, C.textPrimary);
    expect((dots[2].decoration! as BoxDecoration).color, C.textPrimary);
    expect((dots[3].decoration! as BoxDecoration).color, isNot(C.textPrimary));
  });

  testWidgets('an errored dot row uses the danger border', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: PinDots(filled: 0, error: true)))));

    final first = tester.widgetList<Container>(find.byType(Container)).first;
    final border = (first.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, const Color(0xFF4A3634));
  });

  testWidgets('the keypad reports digits and backspace', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PinKeypad(onKey: pressed.add))));

    await tester.tap(find.text('7'));
    await tester.tap(find.text('0'));
    await tester.tap(find.text('⌫'));

    expect(pressed, ['7', '0', '⌫']);
  });

  testWidgets('the keypad has a blank cell where the spec shows one',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PinKeypad(onKey: (_) {}))));

    // 1-9, blank, 0, backspace.
    expect(find.byType(InkWell), findsNWidgets(12));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });
}
