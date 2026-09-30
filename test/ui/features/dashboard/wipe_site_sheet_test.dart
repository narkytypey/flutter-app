import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/features/dashboard/views/wipe_site_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSheet(WidgetTester tester, {VoidCallback? onWipe, VoidCallback? onCancel}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: WipeSiteSheet(onWipe: onWipe ?? () {}, onCancel: onCancel ?? () {}),
      ),
    ),
  ));
}

void main() {
  // Approved by the user on 2026-09-30, word for word.
  testWidgets('shows the approved copy', (tester) async {
    await _pumpSheet(tester);

    expect(find.text("Wipe this site's data?"), findsOneWidget);
    expect(find.text('Its logins, storage and downloads are destroyed. The site stays in its workspace.'),
        findsOneWidget);
    expect(find.text('Wipe'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  // Jade is live state or the single affirmative action. Wiping is neither.
  testWidgets('uses no jade', (tester) async {
    await _pumpSheet(tester);

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(C.jade), reason: text.data);
    }
    for (final pill in tester.widgetList<PillButton>(find.byType(PillButton))) {
      expect(pill.tone, isNot(PillTone.primary));
    }
  });

  testWidgets('Wipe and Cancel each report their own choice', (tester) async {
    final taps = <String>[];
    await _pumpSheet(tester, onWipe: () => taps.add('wipe'), onCancel: () => taps.add('cancel'));

    await tester.tap(find.text('Wipe'));
    await tester.tap(find.text('Cancel'));

    expect(taps, ['wipe', 'cancel']);
  });

  group('confirmWipeSite', () {
    // The open vault has its own navigator inside AppGate (6a5f013), so a
    // lock or panic tears down whatever is on it. The sheet must go there,
    // never on the root navigator.
    late GlobalKey<NavigatorState> vaultNavigator;
    late bool? answer;

    Future<void> pumpVault(WidgetTester tester) async {
      vaultNavigator = GlobalKey<NavigatorState>();
      answer = null;
      await tester.pumpWidget(MaterialApp(
        home: Navigator(
          key: vaultNavigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => answer = await confirmWipeSite(context),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the open vault\'s own navigator', (tester) async {
      await pumpVault(tester);

      expect(Navigator.of(tester.element(find.byType(WipeSiteSheet))), vaultNavigator.currentState);
    });

    testWidgets('answers yes only for Wipe', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Wipe'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
      expect(find.byType(WipeSiteSheet), findsNothing);
    });

    testWidgets('answers no for Cancel', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('answers no when dismissed', (tester) async {
      await pumpVault(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
      expect(find.byType(WipeSiteSheet), findsNothing);
    });
  });
}
