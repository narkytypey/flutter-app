import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/widgets/monogram.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/core/widgets/pin_keypad.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/lock/views/lock_body.dart';
import 'package:container/ui/features/settings/views/decoy_resync_pin_screen.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';
import 'package:container/ui/features/setup/views/setup_pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen sizes and text scales a phone can really have (2026-10-05's
/// responsiveness run): landscape, and Android's largest font size.
Future<void> _pump(WidgetTester tester, Widget child,
    {required Size size, double textScale = 1}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

const _landscape = Size(915, 412);
const _portrait = Size(412, 915);

/// The dots are on screen, not scrolled out of view, and the keypad is
/// beside them.
void _dotsBesideKeypad(WidgetTester tester) {
  final screen = Offset.zero & _landscape;
  final dots = tester.getRect(find.byType(PinDots));
  final keypad = tester.getRect(find.byType(PinKeypad));
  expect(screen.contains(dots.topLeft) && screen.contains(dots.bottomRight), isTrue,
      reason: 'dots at $dots');
  expect(keypad.left, greaterThan(dots.right));
}

void main() {
  group('PIN screens in landscape (user\'s ruling 2026-10-05)', () {
    for (final mood in LockMood.values) {
      testWidgets('the lock screen, $mood: the dots beside the keypad', (tester) async {
        await _pump(
          tester,
          LockBody(
            mood: mood,
            filled: 2,
            onKey: (_) {},
            onBiometric: () {},
            openSessions: 3,
            secondsUntilLock: 40,
            biometricAvailable: true,
          ),
          size: _landscape,
        );
        _dotsBesideKeypad(tester);
      });
    }

    testWidgets('setup: dots beside the keypad, Continue under it', (tester) async {
      await _pump(
        tester,
        SetupPinScreen(
          filled: 6,
          onKey: (_) {},
          onContinue: () {},
          notice: 'Choose a different PIN',
        ),
        size: _landscape,
      );
      _dotsBesideKeypad(tester);
      final keypad = tester.getRect(find.byType(PinKeypad));
      final cont = tester.getRect(find.text('Continue'));
      expect(cont.top, greaterThan(keypad.bottom));
      expect(cont.bottom, lessThanOrEqualTo(_landscape.height));
    });

    testWidgets('the decoy PIN screen: dots beside the keypad', (tester) async {
      await _pump(tester, DecoyResyncPinScreen(filled: 1, error: true, onKey: (_) {}),
          size: _landscape);
      _dotsBesideKeypad(tester);
    });

    testWidgets('portrait keeps the canvas layout: the keypad under the dots', (tester) async {
      await _pump(
        tester,
        LockBody(mood: LockMood.normal, filled: 0, onKey: (_) {}, onBiometric: () {}),
        size: _portrait,
      );
      final dots = tester.getRect(find.byType(PinDots));
      final keypad = tester.getRect(find.byType(PinKeypad));
      expect(keypad.top, greaterThan(dots.bottom));
    });
  });

  testWidgets("at the largest font size a monogram's two letters stay inside it",
      (tester) async {
    await _pump(tester, const Center(child: Monogram('Wm')), size: _portrait, textScale: 2);
    final box = tester.getRect(find.byType(Monogram));
    final letters = tester.getRect(find.text('Wm'));
    expect(box.contains(letters.topLeft) && box.contains(letters.bottomRight), isTrue,
        reason: 'letters at $letters in $box');
  });

  testWidgets("at the largest font size 2a's tab labels stay on one line", (tester) async {
    await _pump(
      tester,
      AddSiteScreen(
        workspaces: const [
          Workspace(id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
        ],
        initial: const Site(
          id: 's', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
          url: 'https://forum.example.com', profileId: 'p',
        ),
        onSave: (_) {},
      ),
      size: const Size(360, 640),
      textScale: 2,
    );
    final oneLine = tester.getRect(find.text('Basics')).height;
    for (final tab in ['Network', 'Privacy', 'Appearance']) {
      expect(tester.getRect(find.text(tab)).height, lessThanOrEqualTo(oneLine), reason: tab);
    }
  });

  // The value pills of 2026-10-06: a long route still fits a small phone at a
  // large text scale, and so does the title.
  for (final scale in [1.3, 2.0]) {
    testWidgets('Settings fits 320x568 at $scale with a long proxy route', (tester) async {
      await _pump(
        tester,
        SettingsScreen(
          biometrics: true, biometricsAvailable: true, autoLockLabel: 'After 15 min',
          decoyEnabled: true, decoySiteCount: 12, hideFromSwitcher: true, panicOnFlip: false,
          onPanicLabel: 'Wipe + lock', searchEngineName: 'Startpage', securityLevelName: 'Safest',
          defaultRouteLabel: 'SOCKS5 · a-very-long-proxy-hostname.example.net:1080',
          defaultRouteMono: true,
          onChanged: (_, __) {}, onTap: (_) {}, onBack: () {},
        ),
        size: const Size(320, 568),
        textScale: scale,
      );
      await tester.scrollUntilVisible(find.text('On panic'), 200);
      expect(tester.takeException(), isNull);
    });
  }
}
