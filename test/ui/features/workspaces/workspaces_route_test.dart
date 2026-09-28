import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/workspaces/views/delete_workspace_sheet.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';
import 'package:container/ui/features/workspaces/views/workspaces_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late FakeContainerEngine engine;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    engine = FakeContainerEngine();
  });

  tearDown(() => database.close());

  // sqflite_common_ffi runs on a real isolate, so every DB round trip must
  // happen inside runAsync; a plain pump never lets it complete.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pump(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    await tester.runAsync(() async {
      await SqliteWorkspaceRepository(database).upsert(const Workspace(
          id: 'ws-work', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep));
      await SqliteSiteRepository(database).upsert(const Site(
          id: 'mail', workspaceId: 'ws-work', name: 'Mail', monogram: 'Ml',
          url: 'https://mail.example.com', profileId: 'profile-mail'));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        containerEngineProvider.overrideWithValue(engine),
      ],
      child: const MaterialApp(home: WorkspacesRoute()),
    ));
    await settle(tester);
  }

  testWidgets('lists the vault\'s workspaces with their stats', (tester) async {
    await pump(tester);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('1 site · cookies kept · 0 MB'), findsOneWidget);
  });

  testWidgets('New workspace opens the form and saving adds a row', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New workspace'));
    await settle(tester);
    expect(tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen)).title,
        'New workspace');

    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.byType(WorkspaceFormScreen), findsNothing);
    expect(find.text('Research'), findsOneWidget);
  });

  testWidgets('tapping a row edits that workspace', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Work'));
    await settle(tester);

    final form = tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen));
    expect(form.title, 'Work');
    expect(form.initialName, 'Work');
    expect(form.initialMarkerIndex, 1);
  });

  testWidgets('long-press, type the name, Delete: gone, and its site wiped', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Work'));
    await settle(tester);
    expect(find.byType(DeleteWorkspaceSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.byType(DeleteWorkspaceSheet), findsNothing);
    expect(find.text('Work'), findsNothing);
    expect(engine.wiped, ['profile-mail']);
  });
}
