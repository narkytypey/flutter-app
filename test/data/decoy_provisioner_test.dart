import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/decoy_provisioner.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase real;
  late AppDatabase decoy;

  setUp(() async {
    real = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    decoy = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);

    await SqliteWorkspaceRepository(real).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, showInDecoy: true));
    await SqliteWorkspaceRepository(real).upsert(const Workspace(
        id: 'ws-secret', name: 'Work', markerIndex: 1,
        storageRule: StorageRule.keep, showInDecoy: false));

    final sites = SqliteSiteRepository(real);
    await sites.upsert(Site(
        id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
        url: 'https://news.example.com', profileId: newProfileId(),
        showInDecoy: true));
    await sites.upsert(Site(
        id: 's2', workspaceId: 'ws', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: newProfileId(),
        showInDecoy: false));
    await sites.upsert(Site(
        id: 's3', workspaceId: 'ws-secret', name: 'Wiki', monogram: 'Wk',
        url: 'https://wiki.internal', profileId: newProfileId(),
        showInDecoy: true));
  });

  tearDown(() async {
    await real.close();
    await decoy.close();
  });

  test('only flagged rows in flagged workspaces are copied', () async {
    final copied = await provisionDecoy(from: real, into: decoy);

    expect(copied, 1);
    final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
    expect(sites.map((s) => s.name), ['News']);
  });

  test('the decoy store carries no visibility flags of its own', () async {
    await provisionDecoy(from: real, into: decoy);

    final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
    expect(sites.single.showInDecoy, isFalse,
        reason: 'rows in the decoy are just rows; nothing is hidden from them');
  });

  test('an unflagged workspace does not appear at all', () async {
    await provisionDecoy(from: real, into: decoy);

    final workspaces = await SqliteWorkspaceRepository(decoy).all();
    expect(workspaces.map((w) => w.name), ['Personal']);
  });

  test('the copied site gets a fresh profile, never the real site\'s',
      () async {
    await provisionDecoy(from: real, into: decoy);

    final realNews =
        (await SqliteSiteRepository(real).inWorkspace('ws')).first;
    final decoyNews =
        (await SqliteSiteRepository(decoy).inWorkspace('ws')).single;
    expect(decoyNews.profileId, isNot(realNews.profileId),
        reason:
            'sharing a WebView profile across vaults would share cookies '
            'and cache between the real and decoy copies of the same site');
  });
}
