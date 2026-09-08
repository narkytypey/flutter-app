import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/features/lock/views/lock_body.dart'
    show LockBody, LockMood;
import 'package:container/ui/features/lock/views/lock_screen.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import 'session_controller_test.dart' show FakeBiometricService;

void main() {
  // Every other test file that opens a `databaseFactoryFfi` database calls
  // this in `setUpAll` first (see e.g. `session_controller_test.dart`).
  // Without it, `AppDatabase.open(factory: databaseFactoryFfi)` hangs
  // forever waiting on the FFI worker isolate instead of failing fast.
  setUpAll(sqfliteFfiInit);

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

  testWidgets('tapping the fingerprint prompt resumes without a PIN',
      (tester) async {
    // A `testWidgets` body runs inside a `FakeAsync` zone, which never
    // delivers real (non-simulated) async events. Both of the real-async
    // calls the plan's own version of this test made therefore never
    // return, and the test dies on the 10-minute timeout — confirmed for
    // the database open by `TimeoutException after 0:10:00 ... dart:isolate
    // _RawReceivePort._handleMessage`, which is the sqflite FFI isolate
    // round-trip nothing is left to complete. Sibling files get away with
    // the identical calls only because they are plain `test()`s, with no
    // fake-async zone.
    //
    // So: the database open goes through `tester.runAsync`, the documented
    // escape hatch for genuinely asynchronous work. The temp directory is
    // dropped altogether instead — `vaultOpenerProvider` is overridden
    // below to ignore its `path` argument entirely, so
    // `documentsDirectoryProvider` only needs a `Directory` to join a path
    // string against and nothing ever touches the filesystem.
    final dir = Directory('lock-screen-test-dir');
    final db = (await tester.runAsync(() => AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    final biometrics = FakeBiometricService();

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialSessionProvider.overrideWithValue(SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          biometricVault: VaultId.a,
          biometricWrappedKey: Uint8List.fromList([1, 2, 3]),
        )),
        documentsDirectoryProvider.overrideWithValue(dir),
        biometricServiceProvider.overrideWithValue(biometrics),
        vaultOpenerProvider.overrideWithValue(
            ({required String path, required Uint8List dataKey}) async => db),
      ],
      child: const MaterialApp(home: LockScreen()),
    ));

    expect(find.text('Use fingerprint'), findsOneWidget);
    await tester.tap(find.text('Use fingerprint'));
    await tester.pumpAndSettle();

    expect(find.byType(LockBody), findsNothing);
  });

  testWidgets('a cancelled fingerprint prompt leaves the lock screen up',
      (tester) async {
    final biometrics = FakeBiometricService()..unwrapSucceeds = false;

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialSessionProvider.overrideWithValue(SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          biometricVault: VaultId.a,
          biometricWrappedKey: Uint8List.fromList([1, 2, 3]),
        )),
        biometricServiceProvider.overrideWithValue(biometrics),
      ],
      child: const MaterialApp(home: LockScreen()),
    ));

    await tester.tap(find.text('Use fingerprint'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
