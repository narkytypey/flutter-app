import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/services/workspace_storage_service.dart';
import 'package:container/ui/features/workspaces/view_models/workspace_actions.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late FakeContainerEngine engine;
  late WorkspaceActions actions;

  const personal = Workspace(
      id: 'ws-personal', name: 'Personal', markerIndex: 0,
      storageRule: StorageRule.keep, sortIndex: 0);
  const work = Workspace(
      id: 'ws-work', name: 'Work', markerIndex: 1,
      storageRule: StorageRule.keep, sortIndex: 1);

  Site site(String id, String workspaceId) => Site(
        id: id, workspaceId: workspaceId, name: id, monogram: 'Xx',
        url: 'https://$id.example.com', profileId: 'profile-$id',
      );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    engine = FakeContainerEngine();
    actions = WorkspaceActions(
      workspaces: SqliteWorkspaceRepository(database),
      sites: SqliteSiteRepository(database),
      engine: engine,
      storage: FakeWorkspaceStorageService({'ws-personal': 12 * 1024 * 1024}),
    );
    await SqliteWorkspaceRepository(database).upsert(personal);
    await SqliteWorkspaceRepository(database).upsert(work);
    await SqliteSiteRepository(database).upsert(site('forum', 'ws-personal'));
    await SqliteSiteRepository(database).upsert(site('mail', 'ws-work'));
    await SqliteSiteRepository(database).upsert(site('docs', 'ws-work'));
  });

  tearDown(() => database.close());

  test('list items carry each workspace\'s stats line, in order', () async {
    final items = await actions.listItems();

    expect(items.map((i) => i.name), ['Personal', 'Work']);
    expect(items.first.statsLine, '1 site · cookies kept · 12 MB');
    expect(items.last.statsLine, '2 sites · cookies kept · 0 MB');
  });

  test('creating a workspace appends it after the existing ones', () async {
    await actions.create(const WorkspaceFormResult(
      name: 'Research', markerIndex: 2, storageRule: StorageRule.wipeOnExit,
      requirePin: true, showInDecoy: false,
    ));

    final all = await SqliteWorkspaceRepository(database).all();
    expect(all.map((w) => w.name), ['Personal', 'Work', 'Research']);
    expect(all.last.storageRule, StorageRule.wipeOnExit);
    expect(all.last.requirePin, isTrue);
    expect(all.last.id, isNot(anyOf('ws-personal', 'ws-work')));
  });

  test('editing a workspace keeps its id and place', () async {
    await actions.update(work, const WorkspaceFormResult(
      name: 'Office', markerIndex: 3, storageRule: StorageRule.keep,
      requirePin: false, showInDecoy: true,
    ));

    final updated = await SqliteWorkspaceRepository(database).byId('ws-work');
    expect(updated, work.copyWith(name: 'Office', markerIndex: 3, showInDecoy: true));
  });

  // Spec 10c: "Logins destroyed" and "Stored data wiped". Deleting the rows
  // alone would leave every site's WebView profile — its cookies — on disk.
  test('deleting a workspace closes and wipes each of its sites first', () async {
    await engine.open(site('mail', 'ws-work'));

    await actions.delete(work);

    expect(engine.closed, contains('mail'));
    expect(engine.wiped, unorderedEquals(['profile-mail', 'profile-docs']));
    expect(await SqliteWorkspaceRepository(database).byId('ws-work'), isNull);
    expect(await SqliteSiteRepository(database).inWorkspace('ws-work'), isEmpty);
    expect(await SqliteSiteRepository(database).inWorkspace('ws-personal'), hasLength(1));
  });
}
