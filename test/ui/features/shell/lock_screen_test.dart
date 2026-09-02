import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/lock/views/lock_screen.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

void main() {
  Future<void> pump(WidgetTester tester, Session initial) {
    // LockBody's fixed Expanded region overflows the 800x600 landscape
    // default in the wrong/afterTimeout moods — cross-plan issue #12, whose
    // fix in `lock_body_test.dart` was a portrait surface. Same here.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(ProviderScope(
      overrides: [initialSessionProvider.overrideWithValue(initial)],
      child: const MaterialApp(home: LockScreen()),
    ));
  }

  testWidgets('renders the mood and counters SessionLocked carries',
      (tester) async {
    await pump(
      tester,
      SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        openSessionCount: 2,
        lockDeadline: DateTime.now().add(const Duration(seconds: 40)),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('2 sessions still open'), findsOneWidget);
  });

  testWidgets('a wrong-PIN mood shows the tries-left count from the gate',
      (tester) async {
    await pump(tester,
        const SessionLocked(mood: LockMood.wrong, gate: AttemptGate(failures: 2)));

    expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
  });

  testWidgets('keypad taps move the dot count before any PIN is complete',
      (tester) async {
    await pump(
        tester, const SessionLocked(mood: LockMood.normal, gate: AttemptGate()));

    await tester.tap(find.text('1').first);
    await tester.tap(find.text('2').first);
    await tester.pump();

    final dots = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(PinDots), matching: find.byType(Container)))
        .toList();
    expect(
        dots.where((c) => (c.decoration! as BoxDecoration).color != null).length,
        2);
  });
}
