import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => database.close());

  test('a fresh database seeds the three workspaces from the spec', () async {
    await seedIfEmpty(database);
    final workspaces = await SqliteWorkspaceRepository(database).all();

    expect(workspaces.map((w) => w.name), ['Personal', 'Work', 'Ephemeral']);
    expect(workspaces.last.storageRule, StorageRule.wipeOnExit);
  });

  test('seeding twice does not duplicate anything', () async {
    await seedIfEmpty(database);
    await seedIfEmpty(database);

    expect((await SqliteWorkspaceRepository(database).all()).length, 3);
  });

  test('the seeded Personal sites keep the design\'s hand-picked monograms', () async {
    await seedIfEmpty(database);
    final personal = (await SqliteWorkspaceRepository(database).all()).first;
    final sites = await SqliteSiteRepository(database).inWorkspace(personal.id);

    expect(sites.map((s) => s.name),
        ['Notes', 'Webmail', 'Forum', 'Reader', 'Bank', 'Marketplace']);
    expect(sites.map((s) => s.monogram),
        ['Nt', 'Wm', 'Fr', 'Rd', 'Bk', 'Mk']);
  });

  test('a site round-trips every field through the database', () async {
    final workspaces = SqliteWorkspaceRepository(database);
    final sites = SqliteSiteRepository(database);

    await workspaces.upsert(const Workspace(
      id: 'w1',
      name: 'Research',
      markerIndex: 1,
      storageRule: StorageRule.keep,
      requirePin: true,
    ));

    final visited = DateTime.utc(2026, 8, 30, 9, 10);
    await sites.upsert(Site(
      id: 's1',
      workspaceId: 'w1',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: newProfileId(),
      cookiePolicy: CookiePolicy.wipeOnExit,
      proxyMode: ProxyMode.socks5,
      proxyHost: '127.0.0.1',
      proxyPort: 9050,
      showInDecoy: true,
      lastVisitedAt: visited,
      sortIndex: 3,
    ));

    final loaded = (await sites.inWorkspace('w1')).single;
    expect(loaded.name, 'Forum');
    expect(loaded.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(loaded.proxyMode, ProxyMode.socks5);
    expect(loaded.proxyHost, '127.0.0.1');
    expect(loaded.proxyPort, 9050);
    expect(loaded.showInDecoy, isTrue);
    expect(loaded.lastVisitedAt, visited);
    expect(loaded.sortIndex, 3);
    expect(loaded.host, 'forum.example.com');
  });

  test('touch updates only the last-visited time', () async {
    final sites = SqliteSiteRepository(database);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'w1', name: 'W', markerIndex: 0, storageRule: StorageRule.keep));
    await sites.upsert(Site(
        id: 's1', workspaceId: 'w1', name: 'N', monogram: 'Nt',
        url: 'https://n.example.com', profileId: newProfileId()));

    final at = DateTime.utc(2026, 8, 30, 12);
    await sites.touch('s1', at);

    final loaded = (await sites.inWorkspace('w1')).single;
    expect(loaded.lastVisitedAt, at);
    expect(loaded.name, 'N');
  });

  test('neither vault file is named for its role', () {
    // Under the coerced-unlock threat model the attacker is looking at the
    // device, so a file called `decoy.db` would give away the whole scheme.
    final names = {vaultFileName(Vault.a), vaultFileName(Vault.b)};

    expect(names.length, 2, reason: 'the two vaults must not share a file');
    for (final name in names) {
      expect(name.toLowerCase(), isNot(contains('decoy')));
      expect(name.toLowerCase(), isNot(contains('real')));
      expect(name.toLowerCase(), isNot(contains('hidden')));
    }
  });

  test('deleting a workspace removes its sites', () async {
    await seedIfEmpty(database);
    final workspaces = SqliteWorkspaceRepository(database);
    final personal = (await workspaces.all()).first;

    await workspaces.delete(personal.id);

    expect(await SqliteSiteRepository(database).inWorkspace(personal.id), isEmpty);
    expect((await workspaces.all()).length, 2);
  });
}
