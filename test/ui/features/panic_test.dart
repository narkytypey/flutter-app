import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/typography.dart';
import 'package:container/ui/features/panic/views/panic_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  testWidgets('panic reports what happened, in past tense', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 3),
        onUnlock: () {},
      ),
    ));

    expect(find.text('Everything closed'), findsOneWidget);
    expect(
      find.text('3 sessions destroyed, temporary storage wiped, app locked.'),
      findsOneWidget,
    );
    expect(find.text('WEBVIEWS'), findsOneWidget);
    expect(find.text('DESTROYED'), findsOneWidget);
    expect(find.text('EPHEMERAL DATA'), findsOneWidget);
    expect(find.text('WIPED'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.panic)).color, C.danger);
    expect(tester.getSize(findGlyph(AppGlyph.panic)), const Size(20, 20));
  });

  testWidgets('there is no confirmation step anywhere on the screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 1),
        onUnlock: () {},
      ),
    ));

    // Spec 3c: "no confirmation dialog, it just happens and reports after".
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('Are you sure'), findsNothing);
    expect(find.text('Unlock'), findsOneWidget);
  });

  // User's ruling 2026-10-05: one session reads singular.
  testWidgets('one destroyed session reads "1 session destroyed"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(report: const PanicReport(sessionsDestroyed: 1), onUnlock: () {}),
    ));
    expect(
      find.text('1 session destroyed, temporary storage wiped, app locked.'),
      findsOneWidget,
    );
  });

  // Restyle v2 §8 (Plan 22 Task 3): panic is not a different colour, and
  // nothing on it is live.
  testWidgets('v2: 3c is on the page colour with text-1 status words',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(report: const PanicReport(sessionsDestroyed: 3), onUnlock: () {}),
    ));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, C.bg);
    for (final word in ['DESTROYED', 'WIPED', 'CLEARED']) {
      expect(tester.widget<Text>(find.text(word)).style!.color, C.textPrimary);
    }
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(C.jade));
    }
    expect(tester.widget<Text>(find.text('Everything closed')).style, T.sheetTitle);
  });

  testWidgets('v2: 3c at 320 x 568 and text scale 2.0 wraps without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(report: const PanicReport(sessionsDestroyed: 12), onUnlock: () {}),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('EPHEMERAL DATA'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });
}
