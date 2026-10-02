import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart' show databaseProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show biometricServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../shell/session_controller_test.dart' show FakeBiometricService;

/// Lets the in-memory database's real IO finish, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('the vault default reads Standard until another is stored, and fails closed', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.standard);

    await SqliteSettingsRepository(database).setString('security_level', 'safer');
    container.invalidate(vaultSecurityLevelProvider);
    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.safer);

    await SqliteSettingsRepository(database).setString('security_level', 'x');
    container.invalidate(vaultSecurityLevelProvider);
    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.safest);
  });

  testWidgets("picking a level in 2d's BROWSING stores it in the open vault and shows it",
      (tester) async {
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      ],
      child: const MaterialApp(home: SettingsRoute()),
    ));
    await _settle(tester);
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget, reason: 'the row value');

    await tester.tap(find.text('Security level'));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsNothing, reason: 'the vault picker has no Default row');
    await tester.tap(find.text('Safest'));
    await tester.pumpAndSettle();
    await _settle(tester);

    final stored = await tester.runAsync(
        () => SqliteSettingsRepository(database).getString('security_level'));
    expect(stored, 'safest');
    expect(find.text('Safest'), findsOneWidget);
  });
}
