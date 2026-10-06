import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/step_progress.dart';
import 'package:container/ui/features/setup/views/setup_decoy_screen.dart';
import 'package:container/ui/features/setup/views/setup_defaults_screen.dart';
import 'package:container/ui/features/setup/views/setup_pin_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  testWidgets('step 1 states that there is no recovery', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetupPinScreen(filled: 3, onKey: (_) {}, onContinue: null),
    ));

    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(
      find.text('Six digits. It encrypts everything stored on this device. '
          'There is no account and no way to recover it, so pick something '
          'you will remember.'),
      findsOneWidget,
    );
  });

  testWidgets('continue is disabled until six digits are entered',
      (tester) async {
    var advanced = 0;
    await tester.pumpWidget(MaterialApp(
      home: SetupPinScreen(filled: 6, onKey: (_) {}, onContinue: () => advanced++),
    ));

    await tester.tap(find.text('Continue'));
    expect(advanced, 1);
  });

  testWidgets("step 2's decoy switch also toggles from its label", (tester) async {
    // Only the switch itself toggled (seen on the emulator 2026-10-02).
    final seen = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: SetupDecoyScreen(
        enabled: false,
        onToggle: seen.add,
        onContinue: () {},
        onSkip: () {},
      ),
    ));

    await tester.tap(find.text('Set up a decoy PIN'));
    expect(seen, [true]);
  });

  testWidgets('step 2 explains the decoy once, in plain words', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetupDecoyScreen(
        enabled: true,
        onToggle: (_) {},
        onContinue: () {},
        onSkip: () {},
      ),
    ));

    expect(find.text('A second PIN, if you want one'), findsOneWidget);
    expect(
      find.text('If someone makes you unlock the app, this PIN opens a plain '
          'board with only the sites you choose. Nothing on it hints that '
          'anything else exists.'),
      findsOneWidget,
    );
    expect(find.text('Skip for now'), findsOneWidget);
    expect(findGlyph(AppGlyph.forward), findsOneWidget);
  });

  testWidgets('step 3 states the four defaults verbatim', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: SetupDefaultsScreen(onFinish: () {})));

    expect(find.text('How sites will behave'), findsOneWidget);
    expect(find.text('Each site gets its own storage'), findsOneWidget);
    expect(find.text('Camera, mic, location and clipboard blocked'), findsOneWidget);
    expect(find.text('Trackers, ads and WebRTC blocked'), findsOneWidget);
    expect(find.text('Nothing is sent anywhere'), findsOneWidget);
    expect(find.text('Add your first site'), findsOneWidget);
    expect(findGlyph(AppGlyph.check), findsNWidgets(4));
  });

  // Restyle v2 §1.2, §5, §8 (Plan 22 Task 2).
  group('v2', () {
    testWidgets('the step bar paints no jade on any step', (tester) async {
      for (final screen in <Widget>[
        SetupPinScreen(filled: 6, onKey: (_) {}, onContinue: () {}),
        SetupDecoyScreen(
            enabled: true, onToggle: (_) {}, onContinue: () {}, onSkip: () {}),
        SetupDefaultsScreen(onFinish: () {}),
      ]) {
        await tester.pumpWidget(MaterialApp(home: screen));
        expect(_jadeIn(tester, find.byType(StepProgress)), isEmpty);
      }
    });

    testWidgets("5a's checks are text-1", (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: SetupDefaultsScreen(onFinish: () {})));
      for (final check in tester.widgetList<AppIcon>(findGlyph(AppGlyph.check))) {
        expect(check.color, C.textPrimary);
      }
    });

    testWidgets('the one jade on each screen is its affirmative action',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupPinScreen(filled: 6, onKey: (_) {}, onContinue: () {}),
      ));
      expect(_jadeIn(tester, find.byType(Scaffold)), hasLength(1));
      expect(_jadeIn(tester, _action('Continue')), hasLength(1));

      // Until six digits are in, nothing is jade.
      await tester.pumpWidget(MaterialApp(
        home: SetupPinScreen(filled: 3, onKey: (_) {}, onContinue: null),
      ));
      expect(_jadeIn(tester, find.byType(Scaffold)), isEmpty);

      await tester.pumpWidget(MaterialApp(
        home: SetupDecoyScreen(
            enabled: true, onToggle: (_) {}, onContinue: () {}, onSkip: () {}),
      ));
      expect(_jadeIn(tester, find.byType(Scaffold)), hasLength(1));
      expect(_jadeIn(tester, _action('Continue')), hasLength(1));

      await tester.pumpWidget(
          MaterialApp(home: SetupDefaultsScreen(onFinish: () {})));
      expect(_jadeIn(tester, find.byType(Scaffold)), hasLength(1));
      expect(_jadeIn(tester, _action('Add your first site')), hasLength(1));
    });

    testWidgets("4b's decoy switch is the v2 AppToggle, on and not jade",
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupDecoyScreen(
            enabled: true, onToggle: (_) {}, onContinue: () {}, onSkip: () {}),
      ));
      final toggle = tester.widget<AppToggle>(find.byType(AppToggle));
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNotNull);
      expect(tester.getSize(find.byType(AppToggle)), const Size(52, 32));
      expect(_jadeIn(tester, find.byType(AppToggle)), isEmpty);
    });

    testWidgets('setup screens have a 20 dp gutter', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: SetupDefaultsScreen(onFinish: () {})));
      expect(tester.getTopLeft(find.byType(StepProgress)).dx, 20);
    });
  });
}

Finder _action(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first;

/// Every jade fill, border, icon or text colour painted at or under [of].
List<Object> _jadeIn(WidgetTester tester, Finder of) {
  final hits = <Object>[];
  bool jade(Color? c) => c == C.jade;
  bool boxJade(Decoration? d) {
    if (d is! BoxDecoration) return false;
    final b = d.border;
    return jade(d.color) ||
        (b is Border &&
            [b.top, b.left, b.right, b.bottom].any((s) => jade(s.color)));
  }

  final elements = [
    ...of.evaluate(),
    ...find
        .descendant(of: of, matching: find.byWidgetPredicate((_) => true))
        .evaluate(),
  ];
  for (final e in elements) {
    final isJade = switch (e.widget) {
      Material(:final color) => jade(color),
      ColoredBox(:final color) => jade(color),
      Container(:final color, :final decoration) =>
        jade(color) || boxJade(decoration),
      DecoratedBox(:final decoration) => boxJade(decoration),
      AppIcon(:final color) => jade(color),
      Text(:final style) => jade(style?.color),
      _ => false,
    };
    if (isJade) hits.add(e.widget);
  }
  return hits;
}
