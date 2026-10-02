import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart' show databaseProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show biometricServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../support/glyph_finders.dart';
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

  test('the setting reads DuckDuckGo until another engine is stored', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(searchEngineProvider.future), SearchEngine.duckDuckGo);

    await SqliteSettingsRepository(database).setString('search_engine', 'startpage');
    container.invalidate(searchEngineProvider);
    expect(await container.read(searchEngineProvider.future), SearchEngine.startpage);
  });

  testWidgets('picking an engine in 2d stores it in the open vault and shows it', (tester) async {
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
    expect(find.text('DuckDuckGo'), findsOneWidget);

    await tester.tap(find.text('Search engine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brave Search'));
    await tester.pumpAndSettle();
    await _settle(tester);

    final stored = await tester.runAsync(
        () => SqliteSettingsRepository(database).getString('search_engine'));
    expect(stored, 'braveSearch');
    expect(find.text('Brave Search'), findsOneWidget);
  });

  testWidgets("2d's back icon pops Settings (restyle spec §4)", (tester) async {
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
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const SettingsRoute())),
            child: const Text('open settings'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.byType(SettingsRoute), findsOneWidget);

    await tester.tap(findIconTap('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsRoute), findsNothing);
    expect(find.text('open settings'), findsOneWidget);
  });
}
