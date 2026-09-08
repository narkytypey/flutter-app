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

  group('resyncDecoy', () {
    test('adds a newly flagged site with a fresh profileId', () async {
      final copied = await resyncDecoy(from: real, into: decoy);

      expect(copied, 1);
      final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
      expect(sites.map((s) => s.name), ['News']);
    });

    test('keeps an already-synced site\'s existing profileId on a second call',
        () async {
      await resyncDecoy(from: real, into: decoy);
      final firstProfile =
          (await SqliteSiteRepository(decoy).byId('s1'))!.profileId;

      final copied = await resyncDecoy(from: real, into: decoy);

      expect(copied, 0, reason: 'nothing new was flagged the second time');
      final secondProfile =
          (await SqliteSiteRepository(decoy).byId('s1'))!.profileId;
      expect(secondProfile, firstProfile,
          reason: 'regenerating it would silently wipe decoy-side cookies '
              'and history for a site that did not actually change');
    });

    test('removes a decoy site whose flag was turned off since the last sync',
        () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteSiteRepository(real).upsert(
        (await SqliteSiteRepository(real).byId('s1'))!.copyWith(showInDecoy: false),
      );

      await resyncDecoy(from: real, into: decoy);

      final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
      expect(sites, isEmpty);
    });

    test('removes every site of a workspace whose flag was turned off',
        () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteWorkspaceRepository(real).upsert(
        (await SqliteWorkspaceRepository(real).byId('ws'))!
            .copyWith(showInDecoy: false),
      );

      await resyncDecoy(from: real, into: decoy);

      expect(await SqliteWorkspaceRepository(decoy).byId('ws'), isNull);
      expect(await SqliteSiteRepository(decoy).inWorkspace('ws'), isEmpty);
    });

    test('never touches a site the owner added directly inside the decoy '
        'session', () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteWorkspaceRepository(decoy).upsert(const Workspace(
          id: 'decoy-only-ws', name: 'Recipes', markerIndex: 2,
          storageRule: StorageRule.keep));
      await SqliteSiteRepository(decoy).upsert(Site(
          id: 'decoy-only-site', workspaceId: 'decoy-only-ws', name: 'Blog',
          monogram: 'Bl', url: 'https://blog.example.com',
          profileId: newProfileId()));

      await resyncDecoy(from: real, into: decoy);

      expect(await SqliteWorkspaceRepository(decoy).byId('decoy-only-ws'),
          isNotNull);
      expect(await SqliteSiteRepository(decoy).byId('decoy-only-site'),
          isNotNull);
    });

    test('an unflagged site in an otherwise-flagged workspace is left '
        'unflagged in the decoy copy', () async {
      await resyncDecoy(from: real, into: decoy);

      final bank = await SqliteSiteRepository(decoy).byId('s2');
      expect(bank, isNull, reason: 's2 was never flagged, so it was never '
          'copied and there is nothing to remove');
    });
  });
}
