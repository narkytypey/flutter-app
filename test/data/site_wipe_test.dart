import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/data/services/site_wipe.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Records close and wipe in one list, so the tests can see their order.
class _OrderedEngine extends FakeContainerEngine {
  final calls = <String>[];

  @override
  Future<void> close(String siteId) async {
    calls.add('close $siteId');
    await super.close(siteId);
  }

  @override
  Future<void> wipe(String profileId) async {
    calls.add('wipe $profileId');
    await super.wipe(profileId);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqliteSiteRepository sites;
  late _OrderedEngine engine;

  const forum = Site(
    id: 'st-forum', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
    url: 'https://forum.example.com', profileId: 'profile-old',
  );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    sites = SqliteSiteRepository(database);
    engine = _OrderedEngine();
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
      id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep, sortIndex: 0,
    ));
    await sites.upsert(forum);
  });

  tearDown(() => database.close());

  group('wipeSavedSite', () {
    test('closes the session before wiping, since a profile in use cannot be deleted', () async {
      await wipeSavedSite(engine: engine, sites: sites, site: forum);

      expect(engine.calls, ['close st-forum', 'wipe profile-old']);
    });

    // A profile loaded this run is only cleared in place and deleted at the
    // next start, and using it again drops it from that journal. So the site
    // gets a new profile, and the old one is left to be deleted whole.
    test('keeps the site and gives it a fresh profile', () async {
      final wiped = await wipeSavedSite(engine: engine, sites: sites, site: forum);

      final row = await sites.byId('st-forum');
      expect(row, isNotNull);
      expect(row!.profileId, isNot('profile-old'));
      expect(row.profileId, wiped.profileId);
      expect(row.name, 'Forum');
      expect(row.url, 'https://forum.example.com');
      expect(row.workspaceId, 'ws-personal');
    });

    test('keeps the site\'s script assignments', () async {
      final scripts = SqliteScriptRepository(database);
      await scripts.upsert(const UserScript(
        id: 'sc-1', name: 'Dark', kind: ScriptKind.css, code: 'body{}',
        runAtDocumentStart: true, enabled: true, appliedSiteIds: ['st-forum'],
      ));

      await wipeSavedSite(engine: engine, sites: sites, site: forum);

      expect((await scripts.byId('sc-1'))!.appliedSiteIds, ['st-forum']);
    });

    // `8b`'s "Last worked" belongs to the data the wipe destroys.
    test('forgets when the site last worked', () async {
      await sites.setLastWorked('st-forum', DateTime.utc(2026, 10, 2, 12));

      await wipeSavedSite(engine: engine, sites: sites, site: forum);

      expect(await sites.lastWorked('st-forum'), isNull);
    });

    test('writes the latest row it is given, not a stale one', () async {
      final edited = forum.copyWith(name: 'Forum (edited)');
      await sites.upsert(edited);

      await wipeSavedSite(engine: engine, sites: sites, site: edited);

      expect((await sites.byId('st-forum'))!.name, 'Forum (edited)');
    });
  });

  group('removeSavedSite', () {
    test('closes and wipes the site before deleting its row', () async {
      await removeSavedSite(engine: engine, sites: sites, site: forum);

      expect(engine.calls, ['close st-forum', 'wipe profile-old']);
      expect(await sites.byId('st-forum'), isNull);
    });
  });
}
