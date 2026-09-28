import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/scripts/views/script_editor_screen.dart';
import 'package:container/ui/features/scripts/views/scripts_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('the next check counts down a week from the newest list', () {
    final now = DateTime(2026, 9, 28);
    FilterList list(int daysAgo) => FilterList(
        id: '$daysAgo', name: 'L', ruleCount: 1, enabled: true,
        category: FilterListCategory.trackers,
        updatedAt: now.subtract(Duration(days: daysAgo)));

    expect(nextFilterCheckInDays([list(9), list(2)], now), 5);
    expect(nextFilterCheckInDays([list(30)], now), 0);
    expect(nextFilterCheckInDays(const [], now), 7);
  });

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
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
      await seedFilterListsIfEmpty(database);
      await SqliteWorkspaceRepository(database).upsert(const Workspace(
          id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
      for (final id in ['forum', 'news']) {
        await SqliteSiteRepository(database).upsert(Site(
            id: id, workspaceId: 'w', name: id == 'forum' ? 'Forum' : 'News',
            monogram: 'Xx', url: 'https://$id.example.com', profileId: 'p-$id'));
      }
      await SqliteScriptRepository(database).upsert(const UserScript(
          id: 'sc1', name: 'Hide sticky headers', kind: ScriptKind.css,
          code: 'header { position: static; }', runAtDocumentStart: true,
          enabled: true, appliedSiteIds: ['forum', 'news']));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const MaterialApp(home: ScriptsRoute()),
    ));
    await settle(tester);
  }

  Future<UserScript?> script(WidgetTester tester, String id) =>
      tester.runAsync<UserScript?>(() => SqliteScriptRepository(database).byId(id));

  testWidgets('shows the vault\'s filter lists and scripts', (tester) async {
    await pump(tester);
    expect(find.text('Cookie notices'), findsOneWidget);
    expect(find.text('Hide sticky headers'), findsOneWidget);
    expect(find.text('Applied to 2 sites'), findsOneWidget);
  });

  testWidgets('toggling a filter list persists it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Social embeds'));
    await settle(tester);

    final lists = await tester.runAsync(() => SqliteFilterListRepository(database).all());
    expect(lists!.firstWhere((l) => l.id == 'fl-social').enabled, isTrue);
  });

  testWidgets('opening a script, dropping a site and saving persists both', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Hide sticky headers'));
    await settle(tester);
    final editor = tester.widget<ScriptEditorScreen>(find.byType(ScriptEditorScreen));
    expect(editor.title, 'Hide sticky headers');
    expect(editor.appliedSites.map((s) => s.name), ['Forum', 'News']);

    await tester.tap(find.text('News ×'));
    await tester.pumpAndSettle();
    expect(find.text('News ×'), findsNothing);
    await tester.tap(find.text('JavaScript'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.byType(ScriptEditorScreen), findsNothing);
    final saved = await script(tester, 'sc1');
    expect(saved!.kind, ScriptKind.js);
    expect(saved.appliedSiteIds, ['forum']);
    expect(saved.enabled, isTrue);
  });

  testWidgets('a new script is only created on Save', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New script'));
    await settle(tester);
    expect(tester.widget<ScriptEditorScreen>(find.byType(ScriptEditorScreen)).title,
        'New script');
    await tester.enterText(find.byType(TextField), 'a { color: red; }');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final all = await tester.runAsync(() => SqliteScriptRepository(database).all());
    expect(all, hasLength(2));
    expect(all!.firstWhere((s) => s.id != 'sc1').code, 'a { color: red; }');
  });

  testWidgets('toggling a script persists it', (tester) async {
    await pump(tester);

    // The script row's switch is the last toggle on the screen.
    await tester.tap(find.byType(AppToggle).last);
    await settle(tester);

    expect((await script(tester, 'sc1'))!.enabled, isFalse);
  });
}
