import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/lock/views/lock_body.dart';

Future<void> _pump(WidgetTester tester, LockBody body) {
  // The default 800x600 flutter_test surface is landscape-shaped and too
  // short for the wrong/afterTimeout moods' extra footnote content, which
  // overflows the fixed Expanded region. This is a phone lock screen, so
  // test at a portrait size instead of shrinking the real layout to fit an
  // unrepresentative canvas.
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(home: body));
}

LockBody _body(LockMood mood, {int triesLeft = 5, int filled = 0}) => LockBody(
      mood: mood,
      filled: filled,
      triesLeft: triesLeft,
      openSessions: 3,
      secondsUntilLock: 40,
      onKey: (_) {},
      onBiometric: () {},
    );

void main() {
  testWidgets('the normal lock says nothing about vaults', (tester) async {
    await _pump(tester, _body(LockMood.normal));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsOneWidget);
    expect(find.textContaining('vault', findRichText: true), findsNothing);
    expect(find.textContaining('decoy'), findsNothing);
    expect(find.textContaining('second'), findsNothing);
  });

  testWidgets('a wrong PIN counts down without naming what is behind it',
      (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 3));

    expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
    expect(
      find.text('After 5 wrong tries the app waits 30 seconds before '
          'accepting another.'),
      findsOneWidget,
    );
    expect(find.text('Fingerprint unavailable'), findsOneWidget);
    expect(find.textContaining('vault'), findsNothing);
  });

  testWidgets('the wrong state clears the dots rather than keeping a count',
      (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 3, filled: 4));

    final label = tester.widget<Text>(find.text('Wrong PIN · 3 tries left'));
    expect(label.style!.color, C.danger);
  });

  testWidgets('returning inside the grace period keeps the sessions',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('3 sessions still open · locks in 40s'), findsOneWidget);
  });

  testWidgets('returning after the timer explains what was destroyed',
      (tester) async {
    await _pump(tester, _body(LockMood.afterTimeout));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Locked after 1 minute in the background'), findsOneWidget);
    expect(
      find.text('Ephemeral sessions were closed and wiped. Saved sites will '
          'reopen where you left them.'),
      findsOneWidget,
    );
  });
}
