import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/setup/views/setup_decoy_screen.dart';
import 'package:container/ui/features/setup/views/setup_defaults_screen.dart';
import 'package:container/ui/features/setup/views/setup_pin_screen.dart';

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
  });
}
