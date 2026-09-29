import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/decoy_provisioner.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';

/// A decoy set up with no sites had no workspaces at all, so `+ Add site`
/// threw on `workspaces.first`. Any vault that opens with none gets Personal.
void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  test('a vault with no workspaces gets Personal', () async {
    await ensureWorkspace(database);

    final workspaces = await SqliteWorkspaceRepository(database).all();
    expect(workspaces, hasLength(1));
    expect(workspaces.single.name, 'Personal');
    expect(workspaces.single.storageRule, StorageRule.keep);
    expect(workspaces.single.showInDecoy, isFalse);
  });

  test('a vault that already has a workspace is left alone', () async {
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'w1', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep));

    await ensureWorkspace(database);

    final workspaces = await SqliteWorkspaceRepository(database).all();
    expect(workspaces.map((w) => w.name), ['Work']);
  });

  test('running it twice still leaves one workspace', () async {
    await ensureWorkspace(database);
    await ensureWorkspace(database);

    expect(await SqliteWorkspaceRepository(database).all(), hasLength(1));
  });

  test('its id is never the seeded real-vault Personal\'s id', () async {
    await ensureWorkspace(database);

    final workspace = (await SqliteWorkspaceRepository(database).all()).single;
    expect(workspace.id, isNot('ws-personal'));
  });

  test('a decoy re-sync keeps it, and the sites added to it', () async {
    final real = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    addTearDown(real.close);
    // The real vault as setup seeds it: nothing flagged for the decoy.
    await seedIfEmpty(real);

    await ensureWorkspace(database);
    final personal = (await SqliteWorkspaceRepository(database).all()).single;
    await SqliteSiteRepository(database).upsert(Site(
        id: newProfileId(), workspaceId: personal.id, name: 'News',
        monogram: 'Nw', url: 'https://news.example.com',
        profileId: newProfileId()));

    await resyncDecoy(from: real, into: database);

    final workspaces = await SqliteWorkspaceRepository(database).all();
    expect(workspaces.map((w) => w.id), [personal.id]);
    final sites = await SqliteSiteRepository(database).inWorkspace(personal.id);
    expect(sites.map((s) => s.name), ['News']);
  });
}
