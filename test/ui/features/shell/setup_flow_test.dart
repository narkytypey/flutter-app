import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/setup/view_models/setup_controller.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:container/ui/features/shell/views/setup_flow.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  final sessions = <({VaultId vault, AppDatabase database})>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup-flow-test');
    vaultStore = VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'));
    sessions.clear();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        setupControllerProvider.overrideWithValue(SetupController(
          vaultStore: vaultStore,
          openVault: ({required String path, required Uint8List dataKey}) =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi),
          pathFor: (vault) => '${dir.path}/${vault.name}.db',
          openSession: ({required VaultId vault, required AppDatabase database}) =>
              sessions.add((vault: vault, database: database)),
        )),
      ],
      child: const MaterialApp(home: SetupFlow()),
    ));
  }

  Future<void> enterSixDigits(WidgetTester tester, List<String> keys) async {
    for (final key in keys) {
      await tester.tap(find.text(key).first);
      await tester.pump();
    }
  }

  testWidgets('starts on step 1, the main PIN', (tester) async {
    await pump(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('skipping the decoy goes straight to the defaults step',
      (tester) async {
    await pump(tester);
    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    expect(find.text('How sites will behave'), findsOneWidget);
  });

  testWidgets('enabling the decoy reuses the PIN screen before the defaults',
      (tester) async {
    await pump(tester);
    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Back on a PIN-entry screen, but now for the decoy — the flow's own
    // state (not this screen) is what makes it the decoy step.
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('finishing with a decoy hands both PINs to the controller once',
      (tester) async {
    // This asserts what `SetupFlow` is responsible for — collecting the two
    // PINs and calling `complete` exactly once — not what provisioning does
    // with them. Driving the real `SetupController` from here cannot work:
    // its chain goes through `sqflite_common_ffi`, whose isolate handshake
    // needs real `Timer`s, and `testWidgets` runs the body under a fake
    // clock that never fires them, so the future never completes no matter
    // how the test pumps or yields. The provisioning itself — both slots
    // filled, vault A handed off, both PINs unlocking their own vault — is
    // covered against the real controller in
    // `test/ui/features/setup/setup_controller_test.dart`.
    final calls = <({String mainPin, String? decoyPin})>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        setupControllerProvider.overrideWithValue(_RecordingSetupController(
          vaultStore: vaultStore,
          openVault: ({required String path, required Uint8List dataKey}) =>
              throw StateError('not reached'),
          pathFor: (vault) => '${dir.path}/${vault.name}.db',
          openSession: ({required VaultId vault, required AppDatabase database}) {},
          calls: calls,
        )),
      ],
      child: const MaterialApp(home: SetupFlow()),
    ));

    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']); // main PIN
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await enterSixDigits(tester, ['9', '8', '7', '6', '5', '4']); // decoy PIN
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Add your first site'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.mainPin, '123456');
    expect(calls.single.decoyPin, '987654');
  });
}

/// Records the call instead of provisioning. See the test above for why the
/// real controller cannot be driven from a widget test.
class _RecordingSetupController extends SetupController {
  const _RecordingSetupController({
    required super.vaultStore,
    required super.openVault,
    required super.pathFor,
    required super.openSession,
    required this.calls,
  });

  final List<({String mainPin, String? decoyPin})> calls;

  @override
  Future<void> complete({required String mainPin, String? decoyPin}) async {
    calls.add((mainPin: mainPin, decoyPin: decoyPin));
  }
}
