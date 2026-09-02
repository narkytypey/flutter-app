import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool decoyConfigured}) {
    // `2d` is a long scrolling list. The default 800x600 test surface is
    // shorter than its content, so the sliver never builds the PANIC rows or
    // the footer into the Element tree and `find.text` sees zero of them —
    // an existence problem, not a visibility one. Same class of bug as
    // cross-plan issue #10.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: decoyConfigured,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        onChanged: (_, __) {},
        onTap: (_) {},
      ),
    ));
  }

  testWidgets('the lock and panic sections read verbatim', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsOneWidget);
    expect(find.text('PIN always available as fallback'), findsOneWidget);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('After 1 min'), findsOneWidget);
    expect(find.text('Change main PIN'), findsOneWidget);

    expect(find.text('PANIC'), findsOneWidget);
    expect(find.text('Trigger by flipping face down'), findsOneWidget);
    expect(find.text('Uses the accelerometer'), findsOneWidget);
    expect(find.text('On panic'), findsOneWidget);
    expect(find.text('Wipe + lock'), findsOneWidget);
  });

  testWidgets('the vault section appears when a decoy is configured',
      (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('VAULT'), findsOneWidget);
    expect(find.text('Decoy vault'), findsOneWidget);
    expect(find.text('A second PIN opens a harmless board'), findsOneWidget);
    expect(find.text('Sites shown in decoy'), findsOneWidget);
    expect(find.text('4 selected'), findsOneWidget);
    expect(find.text('Hide from app switcher'), findsOneWidget);
  });

  testWidgets('the footer states the privacy position', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(
      find.text('Nothing leaves this device. There is no account and no sync.'),
      findsOneWidget,
    );
  });
}
