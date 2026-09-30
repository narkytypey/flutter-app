import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/core/widgets/step_progress.dart';
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/settings/views/change_pin_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettings extends SettingsController {
  _FakeSettings(super.ref, {this.verify = const ChangePinVerified(), this.change = const ChangePinDone()});

  final ChangePinOutcome verify;
  ChangePinOutcome change;
  final verified = <String>[];
  final changes = <(String, String)>[];

  @override
  Future<ChangePinOutcome> verifyCurrentPin(String pin) async {
    verified.add(pin);
    return verify;
  }

  @override
  Future<ChangePinOutcome> changePin({required String current, required String replacement}) async {
    changes.add((current, replacement));
    return change;
  }
}

/// Change main PIN (user's ruling, 2026-09-30): the current PIN, then the new
/// one twice on setup's PIN screen, without its step bar.
void main() {
  late _FakeSettings settings;

  Future<void> pump(WidgetTester tester, {ChangePinOutcome verify = const ChangePinVerified(),
      ChangePinOutcome change = const ChangePinDone()}) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith((ref) => settings = _FakeSettings(ref, verify: verify, change: change)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const ChangePinRoute())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('current PIN, new PIN twice, then back to Settings', (tester) async {
    await pump(tester);
    expect(find.text('Enter your PIN'), findsOneWidget);

    await type(tester, '111111');
    expect(settings.verified, ['111111']);
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(find.byType(StepProgress), findsNothing);

    await type(tester, '333333');
    await next(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);

    await type(tester, '333333');
    await next(tester);

    expect(settings.changes, [('111111', '333333')]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a wrong current PIN stays on step 1 with the lock screen\'s line', (tester) async {
    await pump(tester, verify: const ChangePinRejected(4));
    await type(tester, '999999');

    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.text('Choose a PIN'), findsNothing);
  });

  testWidgets('a confirmation that does not match starts the new PIN again, dots red', (tester) async {
    await pump(tester);
    await type(tester, '111111');
    await type(tester, '333333');
    await next(tester);
    await type(tester, '444444');
    await next(tester);

    expect(settings.changes, isEmpty);
    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 0);
    expect(dots.error, isTrue);

    // Typing again clears the red, and a matching pair goes through.
    await type(tester, '5');
    expect(tester.widget<PinDots>(find.byType(PinDots)).error, isFalse);
    await type(tester, '55555');
    await next(tester);
    await type(tester, '555555');
    await next(tester);
    expect(settings.changes, [('111111', '555555')]);
  });

  testWidgets('a new PIN that would open the other vault is refused without saying why', (tester) async {
    await pump(tester, change: const ChangePinClash());
    await type(tester, '111111');
    await type(tester, '222222');
    await next(tester);
    await type(tester, '222222');
    await next(tester);

    expect(find.text('Choose a different PIN'), findsOneWidget);
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);
    expect(find.text('open'), findsNothing);
  });
}
