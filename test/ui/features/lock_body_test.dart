import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/typography.dart';
import 'package:container/ui/features/lock/views/lock_body.dart';

import '../../support/glyph_finders.dart';

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

LockBody _body(
  LockMood mood, {
  int triesLeft = 5,
  int filled = 0,
  int openSessions = 3,
  bool biometricAvailable = false,
  VoidCallback onBiometric = _defaultOnBiometric,
}) => LockBody(
      mood: mood,
      filled: filled,
      triesLeft: triesLeft,
      openSessions: openSessions,
      secondsUntilLock: 40,
      onKey: (_) {},
      onBiometric: onBiometric,
      biometricAvailable: biometricAvailable,
    );

void _defaultOnBiometric() {}

void main() {
  testWidgets('the normal lock says nothing about vaults', (tester) async {
    await _pump(tester, _body(LockMood.normal));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsNothing);
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
    expect(find.text('Use fingerprint'), findsNothing);
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

  // User's ruling 2026-10-05: one try reads singular.
  testWidgets('one try left reads "1 try left"', (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 1));
    expect(find.text('Wrong PIN · 1 try left'), findsOneWidget);
  });

  // User's ruling 2026-10-05: one session reads singular.
  testWidgets('one open session reads "1 session still open"', (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack, openSessions: 1));
    expect(find.text('1 session still open · locks in 40s'), findsOneWidget);
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
    expect(find.text('Use fingerprint'), findsNothing);
  });

  testWidgets('welcomeBack offers fingerprint only when biometrics is available',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack, biometricAvailable: true));

    expect(find.text('Use fingerprint'), findsOneWidget);
  });

  testWidgets('welcomeBack hides fingerprint when biometrics is unavailable',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack));

    expect(find.text('Use fingerprint'), findsNothing);
  });

  testWidgets('tapping the fingerprint prompt calls onBiometric', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      _body(LockMood.welcomeBack,
          biometricAvailable: true, onBiometric: () => tapped = true),
    );

    await tester.tap(find.text('Use fingerprint'));
    expect(tapped, isTrue);
  });

  testWidgets('after the timer, the line names the auto-lock that fired', (tester) async {
    await _pump(
      tester,
      LockBody(
        mood: LockMood.afterTimeout,
        filled: 0,
        onKey: (_) {},
        onBiometric: _defaultOnBiometric,
        lockedAfter: AutoLockPolicy.fifteenMinutes,
      ),
    );
    expect(find.text('Locked after 15 minutes in the background'), findsOneWidget);
    expect(find.text('Locked after 1 minute in the background'), findsNothing);
  });

  testWidgets('the vault mark is a drawn case, text-1, and danger after a wrong PIN', (tester) async {
    await _pump(tester, _body(LockMood.normal));
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.vault)).color, C.textPrimary);
    expect(tester.getSize(findGlyph(AppGlyph.vault)), const Size(20, 20));

    await _pump(tester, _body(LockMood.wrong, triesLeft: 3));
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.vault)).color, C.danger);
  });

  testWidgets('the fingerprint is a drawn jade mark above its words', (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack, biometricAvailable: true));

    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.fingerprint)).color, C.jade);
    expect(find.text('Use fingerprint'), findsOneWidget);
    expect(tester.getCenter(findGlyph(AppGlyph.fingerprint)).dy,
        lessThan(tester.getCenter(find.text('Use fingerprint')).dy));
  });

  // Restyle v2 §3.2, §5, §8 (Plan 22 Task 1).
  testWidgets('v2: headlines are step titles, notes body-muted, counts in Mono',
      (tester) async {
    await _pump(tester, _body(LockMood.normal));
    expect(tester.widget<Text>(find.text('Enter your PIN')).style, T.stepTitle);

    await _pump(tester, _body(LockMood.wrong, triesLeft: 3));
    final wrong = tester.widget<Text>(find.text('Wrong PIN · 3 tries left'));
    expect(wrong.style!.fontSize, T.stepTitle.fontSize);
    expect(wrong.style!.color, C.danger);
    expect(_monoSpans(wrong), ['3']);
    expect(
      tester
          .widget<Text>(find.text('After 5 wrong tries the app waits 30 seconds '
              'before accepting another.'))
          .style,
      T.bodyMuted,
    );

    await _pump(tester, _body(LockMood.welcomeBack));
    expect(tester.widget<Text>(find.text('Welcome back')).style, T.stepTitle);
    final open = tester.widget<Text>(find.text('3 sessions still open · locks in 40s'));
    expect(open.style, T.bodyMuted);
    expect(_monoSpans(open), ['3', '40']);
  });

  testWidgets('v2: nothing on the lock screens is jade but the fingerprint',
      (tester) async {
    for (final mood in LockMood.values) {
      await _pump(tester, _body(mood));
      for (final icon in tester.widgetList<AppIcon>(find.byType(AppIcon))) {
        expect(icon.color, isNot(C.jade), reason: '\$mood');
      }
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(C.jade), reason: '\$mood');
      }
    }
  });

  testWidgets('v2: the lock screen has a 20 dp gutter', (tester) async {
    await _pump(tester, _body(LockMood.afterTimeout));
    final panel = find.ancestor(
        of: find.text('Locked after 1 minute in the background'),
        matching: find.byType(Container)).first;
    expect(tester.getTopLeft(panel).dx, 20);
    expect(tester.getTopRight(panel).dx, 400 - 20);
  });
}

List<String> _monoSpans(Text text) {
  final out = <String>[];
  text.textSpan!.visitChildren((span) {
    if (span is TextSpan &&
        span.style?.fontFamily == T.value.fontFamily &&
        span.text != null) {
      out.add(span.text!);
    }
    return true;
  });
  return out;
}
